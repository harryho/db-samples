/**
 * Create tiny dataset for demo application
 */
const fs = require("fs");
const HOME = process.env.HOME;
const CWD = process.cwd();
const db = require("../json/json_data.min.json");

const camelCase = (s) => {
  if (typeof s !== "string") return "";
  return s.charAt(0).toLowerCase() + s.slice(1);
};

let content = "";
let tinyDB = {};

// Get count before shrinking
Object.keys(db).forEach((key) => {
  let k = camelCase(key);

  console.log(k, db[key].length);
  tinyDB[k] = [...db[key]];
});

const customerIds = [1, 2, 11, 13, 23,  35, 43, 53, 72, 73, 83];
let orderIds = []; 
let productIds = [];

// console.log( key , db[key].length)
["customer", "salesOrder", "orderDetail", "product"].forEach((key) => {
  if (key === "customer") {
    tinyDB[key] = tinyDB[key].filter((c) => customerIds.includes(c.entityId));
  }
  if (key === "salesOrder") {
    tinyDB[key] = tinyDB[key].filter((s) => customerIds.includes(s.customerId));
    orderIds = [ ...new Set( tinyDB[key].reduce((a, e) => [...a, e.entityId], []))];
  }

  if (key === "orderDetail") {
    tinyDB[key] = tinyDB[key].filter((o) => orderIds.includes(o.orderId));
    productIds = [ ...new Set( tinyDB[key].reduce((a, e) => [...a, e.productId], []))];
  }

  if (key === "product") {

    tinyDB[key] = tinyDB[key].filter((o) => productIds.includes(o.entityId));
  }

});


console.log("###########################################");

Object.keys(tinyDB).forEach((key) => {
  console.log(key, tinyDB[key].length);
});

fs.writeFile(
  `${CWD}/json/json_tiny.json`,
  JSON.stringify(tinyDB),
  "utf-8",
  function (err) {
    if (err) throw err;
    console.log("Done!");
  }
);
