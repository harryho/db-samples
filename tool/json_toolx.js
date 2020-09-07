/**
 * This program is to generate a bash script 
 * which will import the data to mongodb 
 */
const fs = require('fs');
const readline = require('readline');

const db = require('../mongo/json_data.json');


console.log(process.env.HOME);

console.log(process.cwd());
const HOME = process.env.HOME;
const CWD = process.cwd();

const NEWLINE = '\n';

let content = '';

const capitalize = s => {
  if (typeof s !== 'string') return '';
  return s.charAt(0).toLowerCase() + s.slice(1);
};

Object.keys(db).forEach(key => {
  let collection = capitalize(key);
  console.log(collection);
  content += `mongoimport -d northwind -c ${collection} --drop --jsonArray --file  ${collection}.json ${NEWLINE}  ${NEWLINE} `;
  const data = db[key];
  console.log(data);
  fs.writeFile(`${CWD}/mongo/${collection}.json`, JSON.stringify(data), 'utf-8', function(err) {
    if (err) throw err;
    console.log('Done!');
  });
});

fs.writeFile(`${CWD}/mongo/mongo_import.sh`, content, 'utf-8', function(err) {
  if (err) throw err;
  console.log('Done!');
});
