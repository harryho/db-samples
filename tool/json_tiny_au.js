/**
 * Create tiny dataset for demo application
 * Replace USA territory with AU data
 */
const fs = require("fs");
const HOME = process.env.HOME;
const CWD = process.cwd();
const db = require("../json/json_tiny.json");

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

// const cids = [1, 2, 11, 13, 23, 35, 43, 53, 72, 73, 83];

const employeeIds=[1,3,4,5,6,8,9]
let orderIds = [];
let productIds = [];
let supplierIds = [];
let categoryIds=[];

//[{
//   "entityId": 1,
//   "regiondescription": "Eastern"
// }, {
//   "entityId": 2,
//   "regiondescription": "Western"
// }, {
//   "entityId": 3,
//   "regiondescription": "Northern"
// }, {
//   "entityId": 4,
//   "regiondescription": "Southern"
// }]
// AU-NSW	 New South Wales	state
// AU-QLD	 Queensland	state
// AU-SA	 South Australia	state
// AU-TAS	 	state
// AU-VIC	 Victoria	state
// AU-WA	 Western Australia	state
// AU-ACT	 Australian Capital Territory	territory
// AU-NT	 Northern Territory	territory

// console.log( key , db[key].length)
["territory","employeeTerritory", "employee",  "salesOrder", 
"orderDetail", "product", "supplier", "category"]
.forEach((key) => {
  if (key === "territory") {
    tinyDB[key] = [
      {
        entityId: 1,
        regionId: 1,
        territoryCode: "NSW",
        territorydescription: "New South Wales",
      },
      {
        entityId: 2,
        regionId: 3,
        territoryCode: "QLD",
        territorydescription: "Queensland",
      },
      {
        entityId: 3,
        regionId: 4,
        territoryCode: "SA",
        territorydescription: "South Australia",
      },
      {
        entityId: 4,
        regionId: 4,
        territoryCode: "TAS",
        territorydescription: "Tasmania",
      },
      {
        entityId: 5,
        regionId: 4,
        territoryCode: "VIC",
        territorydescription: "Western Australia",
      },
      {
        entityId: 6,
        regionId: 2,
        territoryCode: "WA",
        territorydescription: "Western Australia",
      },
      {
        entityId: 7,
        regionId: 1,
        territoryCode: "ACT",
        territorydescription: "Australian Capital Territory",
      },
      {
        entityId: 7,
        regionId: 3,
        territoryCode: "NT",
        territorydescription: "Northern Territory",
      },
    ];
  }

  if (key === "employeeTerritory") {
    tinyDB[key] = [
      {
        entityId: 1,
        employeeId: 1,
        territoryCode: "NSW",
      },
      // {
      //   entityId: 2,
      //   employeeId: 2,
      //   territoryCode: "NSW",
      // },
      {
        entityId: 3,
        employeeId: 3,
        territoryCode: "QLD",
      },
      {
        entityId: 4,
        employeeId: 4,
        territoryCode: "ACT",
      },
      {
        entityId: 5,
        employeeId: 5,
        territoryCode: "NT",
      },
      {
        entityId: 6,
        employeeId: 6,
        territoryCode: "VIC",
      },
      // {
      //   entityId: 7,
      //   employeeId: 7,
      //   territoryCode: "VIC",
      // },
      {
        entityId: 8,
        employeeId: 8,
        territoryCode: "WA",
      },
      {
        entityId: 9,
        employeeId: 9,
        territoryCode: "TAS",
      },
    ];
  }

  if (key==="employee"){
    tinyDB[key] = tinyDB[key].filter((s) => employeeIds.includes(s.entityId));
  }

  if (key === "salesOrder") {
    tinyDB[key] = tinyDB[key].filter((s) => employeeIds.includes(s.employeeId));
    orderIds = [ ...new Set( tinyDB[key].reduce((a, e) => [...a, e.entityId], []))];
  }

  if (key === "orderDetail") {
    tinyDB[key] = tinyDB[key].filter((o) => orderIds.includes(o.orderId));
    productIds = [ ...new Set( tinyDB[key].reduce((a, e) => [...a, e.productId], []))];
  }

  if (key === "product") {
    tinyDB[key] = tinyDB[key].filter((o) => productIds.includes(o.entityId));
    supplierIds = [ ...new Set( tinyDB[key].reduce((a, e) => [...a, e.supplierId], []))];
    categoryIds = [ ...new Set( tinyDB[key].reduce((a, e) => [...a, e.categoryId], []))];
  }

  if (key === "supplier") {
    tinyDB[key] = tinyDB[key].filter((o) => supplierIds.includes(o.entityId));
   }

   if (key === "category") {
    tinyDB[key] = tinyDB[key].filter((o) => categoryIds.includes(o.entityId));
   }
});

console.log("###########################################");

Object.keys(tinyDB).forEach((key) => {
  console.log(key, tinyDB[key].length);
});

fs.writeFile(
  `${CWD}/json/json_tiny_au.json`,
  JSON.stringify(tinyDB),
  "utf-8",
  function (err) {
    if (err) throw err;
    console.log("Done!");
  }
);
