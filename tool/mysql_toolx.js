const fs = require('fs');
const readline = require('readline');

console.log(process.env.HOME);

console.log(process.cwd());
const CWD = process.cwd();

const NEWLINE = '\n';

const files = [];
  const tmpTale = `
DROP TEMPORARY TABLE IF EXISTS tmp_json_data;

CREATE TEMPORARY TABLE tmp_json_data (
  jsonText TEXT,
  tableName VARCHAR(100)
);`;

  let query = '';
  const insertTmpTable = `
INSERT INTO tmp_json_data (
    jsonText,
    tableName
) 
SELECT 
json_object(`;

  const outfile = ' INTO OUTFILE ';
  const from = ' FROM ';
  const resultQuery = `
SET SESSION  group_concat_max_len = 999096;

SELECT concat('"',j.tableName,'":[', j.jtxt, '],')
INTO OUTFILE '/var/lib/mysql-files/json_data.json'
FROM (
SELECT tableName, group_concat(jsonText) jtxt
FROM tmp_json_data 
GROUP BY tableName ) AS j
  `;

function processFile(inputFile) {
  const instream = fs.createReadStream(inputFile),
    outstream = new (require('stream'))(),
    rl = readline.createInterface(instream, outstream);

  let ct = 0;
  
  let tbl = '';

  var keyName = key => "'" + key + "',";

  var parseLine = line => {
    let colName = line
      .trim()
      .split(' ')[0]
      .trim();
    query += `${NEWLINE}   ${keyName(colName)}  ${colName},`;
  };

  var output = newTxt => {
    fs.writeFile(`${CWD}/mysql/export_json.sql`, newTxt, 'utf-8', function(err) {
      if (err) throw err;
      console.log('Done!');
    });
  };

  let tableDef = 0;

  rl.on('line', function(line) {
    if (line.includes('CREATE TABLE ') && tableDef === 0) {
      tableDef = 1;

      tbl = line
        .trim()
        .substr('CREATE TABLE '.length)
        .split(' ')[0];

      query += `${NEWLINE} ${insertTmpTable} `;

      return;
    }

    if (tableDef === 1) {
      if (!line.includes('PRIMARY KEY')) {
        parseLine(line);
      } else {
        tableDef = 0;
        query = query.substr(0, query.length - 1);
        query += `${NEWLINE} ) as json, '${tbl}' `; 
        query += `${NEWLINE} ${from} ${tbl} ; ${NEWLINE}  `;
      }
    }

    ct++;
  });

  rl.on('close', function(line) {
    query = `${tmpTale} ${query} ${resultQuery}`;
    console.log(query);
    output(query);
  });
}

processFile(`${CWD}/mysql/${INPUT_FILE}`);
