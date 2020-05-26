const FlightSuretyApp = artifacts.require("FlightSuretyApp");
const FlightSuretyData = artifacts.require("FlightSuretyData");
const fs = require("fs");

// module.exports = function (deployer) {
//   let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
//   deployer.deploy(FlightSuretyData).then(() => {
//     return deployer.deploy(FlightSuretyApp).then(() => {
//       let config = {
//         localhost: {
//           url: "http://localhost:8545",
//           dataAddress: FlightSuretyData.address,
//           appAddress: FlightSuretyApp.address,
//         },
//       };
//       fs.writeFileSync(
//         __dirname + "/../src/dapp/config.json",
//         JSON.stringify(config, null, "\t"),
//         "utf-8"
//       );
//       fs.writeFileSync(
//         __dirname + "/../src/server/config.json",
//         JSON.stringify(config, null, "\t"),
//         "utf-8"
//       );
//     });
//   });
// };

// module.exports = function (deployer, network, accounts) {
//   let firstAirline = "0xf17f52151EbEF6C7334FAD080c5704D77216b732";
//   deployer.deploy(FlightSuretyData).then(() => {
//     return deployer
//       .deploy(FlightSuretyApp, FlightSuretyData.address)
//       .then(() => {
//         let config = {
//           localhost: {
//             url: "http://localhost:8545",
//             dataAddress: FlightSuretyData.address,
//             appAddress: FlightSuretyApp.address,
//           },
//         };
//         fs.writeFileSync(
//           __dirname + "/../src/dapp/config.json",
//           JSON.stringify(config, null, "\t"),
//           "utf-8"
//         );
//         fs.writeFileSync(
//           __dirname + "/../src/server/config.json",
//           JSON.stringify(config, null, "\t"),
//           "utf-8"
//         );
//       });
//   });
// };

// const FlightSuretyApp = artifacts.require("FlightSuretyApp");
// const FlightSuretyData = artifacts.require("FlightSuretyData");

// module.exports = async function (deployer, network, accounts) {
//   await deployer.deploy(FlightSuretyData);
//   await deployer.deploy(FlightSuretyApp, FlightSuretyData.address);

//   // authorize FlightSuretyApp contract
//   const instance = await FlightSuretyData.deployed();
//   await instance.authorizeContract(FlightSuretyApp.address, {
//     from: accounts[0],
//   });
// };

module.exports = function (deployer) {
  deployer.deploy(FlightSuretyData).then(() => {
    return deployer
      .deploy(FlightSuretyApp, FlightSuretyData.address)
      .then(async () => {
        const instances = await Promise.all([
          FlightSuretyData.deployed(),
          FlightSuretyApp.deployed(),
        ]);
        // App Contract needs to be added to map of authorized ones in Data Contract
        // let result = await instances[0].authorizeCaller(
        //   FlightSuretyApp.address
        // );

        let config = {
          localhost: {
            url: "http://localhost:8545",
            dataAddress: FlightSuretyData.address,
            appAddress: FlightSuretyApp.address,
          },
        };
        fs.writeFileSync(
          __dirname + "/../src/dapp/config.json",
          JSON.stringify(config, null, "\t"),
          "utf-8"
        );
        fs.writeFileSync(
          __dirname + "/../src/server/config.json",
          JSON.stringify(config, null, "\t"),
          "utf-8"
        );
      });
  });
};
