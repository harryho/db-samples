#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Recreate the MS SQL Server container with a fresh Northwind database.

.DESCRIPTION
    Stops and removes the existing MS SQL Server container, removes the data volume,
    and reinitializes the container with a fresh Northwind database. All existing
    data will be removed.

.NOTES
    This script must be run from the db-samples directory where docker-compose.yml
    is located. Equivalent to renew-mssql.sh for PowerShell environments.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Write-Host '=========================================='
Write-Host 'Recreating MS SQL Server Container (mssql-infra)'
Write-Host '=========================================='
Write-Host ''

# Check if docker-compose.yml exists
if (-not (Test-Path -Path 'docker-compose.yml' -PathType Leaf)) {
    Write-Host 'Error: docker-compose.yml not found in current directory'
    Write-Host 'Please run this script from the db-samples directory'
    exit 1
}

# Check if docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host 'Error: docker command not found'
    Write-Host 'Please install Docker Desktop and ensure it is running'
    exit 1
}

# Check if docker-compose is available
if (-not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
    Write-Host 'Error: docker-compose command not found'
    Write-Host 'Please install docker-compose'
    exit 1
}


# Stop and remove only the mssql-infra container
Write-Host '1. Stopping and removing existing mssql-infra container...'
try {
    & docker-compose stop mssql 2>&1 | Out-Null
    & docker-compose rm -f mssql 2>&1 | Out-Null
} catch {
    Write-Warning "Failed to stop/remove container: $_"
}

# Remove the volume to ensure fresh data
Write-Host ''
Write-Host '2. Removing data volume for fresh installation...'
try {
    & docker volume rm db-samples_mssql_data 2>$null | Out-Null
} catch {
    Write-Host '   (No existing volume to remove)'
}

# Start the mssql-infra container
Write-Host ''
Write-Host '3. Starting mssql-infra container...'
try {
    & docker-compose up -d mssql
    if ($LASTEXITCODE -ne 0) {
        throw "docker-compose up failed with exit code $LASTEXITCODE"
    }
    Write-Host '   ✓ mssql-infra container started.'
} catch {
    Write-Host "   ✗ Failed to start container: $_"
    exit 1
}

Write-Host ''
Write-Host '=========================================='
Write-Host '✓ Success!'
Write-Host '=========================================='
Write-Host 'mssql-infra container is running.'
Write-Host 'To stop: docker-compose down'
Write-Host '=========================================='
