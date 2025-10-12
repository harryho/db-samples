#!/usr/bin/env pwsh

<#!
.SYNOPSIS
    Renew the Northwind database from the bundled northwind.sql script.

.DESCRIPTION
    Drops the existing Northwind database (if present), recreates it, and loads
    data from northwind.sql. Attempts to use the local sqlcmd utility when
    available; otherwise, falls back to the mssql-infra Docker container
    shipped with this repository.

.NOTES
    Equivalent behaviour to renew-northwind.sh, adapted for PowerShell.
#>

[CmdletBinding()]
param (
    [string]$Server   = ${env:MSSQL_SERVER}   ?? 'localhost',
    [string]$Port     = ${env:MSSQL_PORT}     ?? '1433',
    [string]$Username = ${env:MSSQL_USER}     ?? 'sa',
    [string]$Password = ${env:MSSQL_PASSWORD} ?? 'YourStrong@Passw0rd',
    [string]$Database = 'northwind'
)

$ErrorActionPreference = 'Stop'
$script:UseDocker = $false
$script:SqlFileInContainer = '/tmp/northwind-renew.sql'
$dockerContainerName = 'mssql-infra'

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
$sqlFile = Join-Path -Path $scriptDir -ChildPath 'northwind.sql'

Write-Host '=========================================='
Write-Host 'Renewing Northwind Database'
Write-Host '=========================================='
Write-Host ""
Write-Host "Server: ${Server}:$Port"
Write-Host "Database: $Database"
Write-Host ""

if (-not (Test-Path -Path $sqlFile -PathType Leaf)) {
    Write-Error "SQL file not found: $sqlFile"
    exit 1
}

function Test-DockerContainer {
    param (
        [string]$ContainerName
    )

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        return $false
    }

    try {
        $containers = & docker ps --format '{{.Names}}' 2>$null
    } catch {
        return $false
    }

    return $containers -contains $ContainerName
}

function Initialize-SqlcmdSource {
    if (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
        Write-Host 'Using local sqlcmd'
        $script:UseDocker = $false
        return
    }

    if (Test-DockerContainer -ContainerName $dockerContainerName) {
        Write-Host 'Using sqlcmd from Docker container'
        $script:UseDocker = $true
        return
    }

    Write-Host 'Error: sqlcmd not found and Docker container ''mssql-infra'' is not running'
    Write-Host ''
    Write-Host 'Options:'
    Write-Host '1. Install SQL Server command-line tools'
    Write-Host '2. Run the Docker container: docker-compose up -d mssql'
    exit 1
}

function Invoke-SqlcmdCommand {
    param (
        [string[]]$Arguments,
        [switch]$ReturnOutput,
        [switch]$Silent
    )

    if ($script:UseDocker) {
        $cmd = 'docker'
        $cmdArgs = @('exec', '-i', $dockerContainerName, '/opt/mssql-tools18/bin/sqlcmd', '-C') + $Arguments
    } else {
        $cmd = 'sqlcmd'
        $cmdArgs = $Arguments
    }

    try {
        if ($ReturnOutput) {
            $output = & $cmd @cmdArgs
            if ($LASTEXITCODE -ne 0) {
                throw "Command failed with exit code $LASTEXITCODE"
            }
            return $output
        }

        if ($Silent) {
            & $cmd @cmdArgs > $null 2>&1
        } else {
            & $cmd @cmdArgs
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
    } catch {
        throw
    }
}

Initialize-SqlcmdSource

Write-Host '1. Testing connection to SQL Server...'
try {
    Invoke-SqlcmdCommand -Arguments @('-S', "$Server,$Port", '-U', $Username, '-P', $Password, '-Q', 'SELECT @@VERSION', '-h', '-1') -Silent
    Write-Host '   ✓ Connected successfully'
} catch {
    Write-Host '   ✗ Failed to connect to SQL Server'
    Write-Host '   Please check your connection parameters'
    exit 1
}

Write-Host ''
Write-Host '2. Dropping existing database (if exists)...'
Invoke-SqlcmdCommand -Arguments @(
    '-S', "$Server,$Port",
    '-U', $Username,
    '-P', $Password,
    '-Q', @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$Database')
BEGIN
    ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$Database];
    PRINT 'Database $Database dropped successfully';
END
ELSE
BEGIN
    PRINT 'Database $Database does not exist';
END
"@,
    '-h', '-1'
) -Silent

Write-Host ''
Write-Host '3. Creating new database...'
try {
    Invoke-SqlcmdCommand -Arguments @(
        '-S', "$Server,$Port",
        '-U', $Username,
        '-P', $Password,
        '-Q', @"
CREATE DATABASE [$Database];
PRINT 'Database $Database created successfully';
"@,
        '-h', '-1'
    ) -Silent
    Write-Host '   ✓ Database created'
} catch {
    Write-Host '   ✗ Failed to create database'
    exit 1
}

Write-Host ''
Write-Host '4. Loading data from northwind.sql...'
Write-Host '   (This may take a minute...)'

try {
    if ($script:UseDocker) {
        Write-Host '   Copying SQL file into container...'
    & docker cp $sqlFile "${dockerContainerName}:${script:SqlFileInContainer}" > $null 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy SQL file into container"
        }

        Invoke-SqlcmdCommand -Arguments @(
            '-S', "$Server,$Port",
            '-U', $Username,
            '-P', $Password,
            '-d', $Database,
            '-i', $script:SqlFileInContainer
        ) -Silent

        & docker exec $dockerContainerName rm -f $script:SqlFileInContainer > $null 2>&1
    } else {
        Invoke-SqlcmdCommand -Arguments @(
            '-S', "$Server,$Port",
            '-U', $Username,
            '-P', $Password,
            '-d', $Database,
            '-i', $sqlFile
        ) -Silent
    }

    Write-Host '   ✓ Data loaded successfully'
} catch {
    Write-Host '   ✗ Failed to load data from SQL file'
    Write-Host '   Run manually to see errors:'
    if ($script:UseDocker) {
        Write-Host "   docker exec -i $dockerContainerName /opt/mssql-tools18/bin/sqlcmd -C -S $Server,$Port -U $Username -P $Password -d $Database -i $script:SqlFileInContainer"
    } else {
        Write-Host "   sqlcmd -S $Server,$Port -U $Username -P $Password -d $Database -i $sqlFile"
    }
    exit 1
}

Write-Host ''
Write-Host '5. Verifying database...'
try {
    $verifyQuery = "SELECT COUNT(*) AS TableCount FROM information_schema.tables WHERE table_type = 'BASE TABLE';"
    
    if ($script:UseDocker) {
        $result = & docker exec -i $dockerContainerName /opt/mssql-tools18/bin/sqlcmd -C -S "$Server,$Port" -U $Username -P $Password -d $Database -Q $verifyQuery -h -1 -W 2>$null
    } else {
        $result = & sqlcmd -S "$Server,$Port" -U $Username -P $Password -d $Database -Q $verifyQuery -h -1 -W 2>$null
    }
    
    # Parse the numeric result
    $tableCount = ($result | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1).Trim()
    
    if ($tableCount -and [int]$tableCount -gt 0) {
        Write-Host "   ✓ Database contains $tableCount tables"
    } else {
        Write-Host "   ⚠ Warning: Unable to verify table count"
    }
} catch {
    Write-Host "   ⚠ Warning: Could not verify database (Error: $($_.Exception.Message))"
    Write-Host "   Database may still have been created successfully."
}

Write-Host ''
Write-Host '=========================================='
Write-Host '✓ Success!'
Write-Host '=========================================='
Write-Host ''
Write-Host "Database '$Database' has been renewed successfully"
Write-Host ''

if ($script:UseDocker) {
    Write-Host 'Connect using:'
    Write-Host "  docker exec -it $dockerContainerName /opt/mssql-tools18/bin/sqlcmd -C -S $Server,$Port -U $Username -P $Password -d $Database"
} else {
    Write-Host 'Connect using:'
    Write-Host "  sqlcmd -S $Server,$Port -U $Username -P $Password -d $Database"
}

Write-Host ''
Write-Host 'Sample query:'
Write-Host '  SELECT TOP 5 * FROM Customers;'
Write-Host '=========================================='
