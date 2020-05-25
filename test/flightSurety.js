let Test = require("../config/testConfig.js");
let BigNumber = require("bignumber.js");

contract("Flight Surety Tests", async (accounts) => {
  let config;
  before("setup contract", async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData._authorizeCaller(
      config.flightSuretyApp.address
    );
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: config.testAddresses[2],
      });
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false;
    try {
      await config.flightSuretyData.setOperatingStatus(false);
    } catch (e) {
      accessDenied = true;
    }
    assert.equal(
      accessDenied,
      false,
      "Access not restricted to Contract Owner"
    );
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyData.setOperatingStatus(false);

    let reverted = false;
    try {
      await config.flightSurety.setTestingMode(true);
    } catch (e) {
      reverted = true;
    }
    assert.equal(reverted, true, "Access not blocked for requireIsOperational");

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true);
  });

  it("(airline) cannot register an Airline using registerAirline() if it is not funded", async () => {
    // ARRANGE;
    let isReverted = false;

    // ACT;
    try {
      await config.flightSuretyApp.registerAirline(
        accounts[2],
        "Some new airline",
        {
          from: config.firstAirline,
        }
      );
    } catch (e) {
      isReverted = true;
    }

    // ASSERT;
    assert.isTrue(
      isReverted,
      true,
      "Airline should not be able to register another airline if it hasn't provided funding"
    );
  });

  // it("(airline) can return a correct number of funded airlines", async () => {
  //   let airline = accounts[6];
  //   let initialFund = new BigNumber(web3.utils.toWei("10", "ether"));
  //   let numOfAirlines;
  //   try {
  //     await config.flightSuretyApp.airlineFunding({
  //       from: airline,
  //       value: initialFund,
  //       gasPrice: 0,
  //     });
  //     await config.flightSuretyApp.airlineFunding({
  //       from: accounts[3],
  //       value: initialFund,
  //       gasPrice: 0,
  //     });

  //     //   numOfAirlines = await config.flightSuretyApp.getNumOfFundedAirlines();
  //   } catch (e) {
  //     console.log(e.message);
  //   }

  //   assert.equal(
  //     numOfAirlines,
  //     1,
  //     "The number of funded airlines is incorrect"
  //   );
  // });

  it("(airline) can check that the airline pays the fund properly", async () => {
    let airline = accounts[9];
    let amount = new BigNumber(web3.utils.toWei("10", "ether"));
    let balance;
    try {
      await config.flightSuretyApp.airlineFunding({
        from: airline,
        value: amount,
        gasPrice: 0,
      });
      balance = await config.flightSuretyApp.checkFunds({
        from: airline,
        gasPrice: 0,
      });
    } catch (e) {
      console.log(e.message);
    }

    let converted = web3.utils.fromWei(balance, "ether");
    assert.equal(
      converted,
      10,
      "The fund by the airlines is not properly loaded"
    );
  });

  it("(airline) can deauthorize a contract using deauthorizeCaller()", async () => {
    // ARRANGE
    let owner = config.owner;
    let airline = accounts[5];
    let eventEmitted = false;

    // ACT
    try {
      await config.flightSuretyApp.authorizeCaller(airline, {
        from: owner,
        gasPrice: 0,
      });
      await config.flightSuretyApp.deauthorizeCaller(airline, {
        from: owner,
        gasPrice: 0,
      });
    } catch (e) {
      console.log("deauthorizedCaller function error", e.message);
    }

    let result = await config.flightSuretyData._isAuthorizedCaller.call(
      airline
    );
    await config.flightSuretyData.contract.events.ContractDeauthorized(
      function () {
        eventEmitted = true;
      }
    );

    // ASSERT
    assert.equal(
      result,
      false,
      "An authorized caller fails to get deauthorized"
    );
    assert.equal(
      eventEmitted,
      true,
      "ContractDeauthorized Event is not emmited"
    );
  });

  // it("delete all the contracts from the funded list for the next testing", async () => {

  // });

  it("(airline) can check if a contract is authorized or not", async () => {
    let contractCaller = config.owner;
    let isAuthorized = false;
    try {
      isAuthorized = await config.flightSuretyData._isAuthorizedCaller(
        contractCaller
      );
    } catch (e) {
      console.log(e.message);
    }

    assert.isTrue(
      isAuthorized,
      "The owner of the contract is incorrectly verified as unauthorized"
    );
  });

  it("(airline, multiparty) can register 4 airlines and vote the 5th airline in", async () => {
    let newAccount = accounts[7];
    let owner = config.owner;
    let initialFund = new BigNumber(web3.utils.toWei("10", "ether"));
    let registerResultForOwner;
    let resultArr = [];

    for (let i = 1; i < 5; i++) {
      // console.log({ i });
      //   // delete all the accounts from the funded list to avoid "The airline has already funded" requirement
      //   await config.flightSuretyData.refund(accounts[i]);
    }

    // // The contract owner registers itself first. However, no need to authorize.
    // await config.flightSuretyApp.airlineFunding({
    //   from: owner,
    //   value: initialFund,
    //   // gasPrice: 0,
    // });

    // registerResultForOwner = await config.flightSuretyApp.registerAirline(
    //   owner,
    //   "First airline",
    //   {
    //     from: owner,
    //     // gasPrice: 0,
    //   }
    // );
    // await config.flightSuretyData._authorizeCaller(newAccount, { from: owner });
    // const result = await config.flightSuretyData._isAuthorizedCaller(
    //   newAccount
    // );
    try {
      const result = await config.flightSuretyApp.test(newAccount, "Yes");
      console.log(result == true);
    } catch {
      throw new Error(error);
    }

    // for (let i = 1; i < 5; i++) {
    //   console.log({ i });

    //   // the contract owner authorizes the airlines
    //   await config.flightSuretyApp.authorizeCaller(accounts[i], {
    //     from: owner,
    //     gasPrice: 0,
    //   });
    //   // the airlines have to first pay the 10 ether deposit to pass the requireFundDeposited modifier in FlightSuretyApp
    //   await config.flightSuretyApp.airlineFunding({
    //     from: accounts[i],
    //     value: initialFund,
    //     gasPrice: 0,
    //   });
    //   // register
    //   const result = await config.flightSuretyApp.registerAirline(
    //     accounts[i],
    //     `airline${i}`,
    //     {
    //       from: accounts[i],
    //       gasPrice: 0,
    //     }
    //   );
    //   resultArr.push(result);
    // }
    // console.log({ registerResultForOwner });
    // console.log(registerResultForOwner == true);
    // assert.isTrue(
    //   registerResultForOwner,
    //   "The contract owner was not registered properly"
    // );
    // for (let i = 0; i < resultArr.length; i++) {
    //   // assert.isTrue(resultArr[i], "The airline1 was not registered properly");
    //   console.log(resultArr[i]);
    // }

    // for (i = 0; i < 2; i++) {
    //   switch (i) {
    //     case 0:
    //       await config.flightSuretyApp.airlineFunding({
    //         from: owner,
    //         value: initialFund,
    //         gasPrice: 0,
    //       });
    //       result0 = await config.flightSuretyApp.registerAirline(
    //         owner,
    //         "First airline",
    //         {
    //           from: owner,
    //           gasPrice: 0,
    //         }
    //       );
    //       break;
    //     case 1:
    //       await config.flightSuretyApp.authorizeCaller(accounts[1], {
    //         from: owner,
    //         gasPrice: 0,
    //       });
    //       await config.flightSuretyApp.airlineFunding({
    //         from: accounts[1],
    //         value: initialFund,
    //         gasPrice: 0,
    //       });
    //       const result1 = await config.flightSuretyApp.registerAirline(
    //         accounts[1],
    //         "Second airline"
    //       );
    //       break;
    //     // case 2:
    //     //   break;
    //     // case 3:
    //     //   break;
    //     // case 4:
    //     //   break;
    //     // case 5:
    //     //   break;

    //     default:
    //       break;
    //   }
    // }
  });

  // let result = await config.flightSuretyData._isAirline.call(newAirline);

  // flightSuretyData ---------------------------------------------------------------------------------------------------------------------------------------

  it("can register an account as an authorized caller using _authorizeCaller()", async () => {
    // ARRANGE
    let contractCaller = accounts[2];
    let eventEmitted = false;

    // ACT
    try {
      await config.flightSuretyData._authorizeCaller(contractCaller);
    } catch (e) {
      console.log("AuthorizeCaller function error", e);
    }

    let result = await config.flightSuretyData._isAuthorizedCaller.call(
      contractCaller
    );

    await config.flightSuretyData.contract.events.ContractAuthorized(
      function () {
        eventEmitted = true;
      }
    );

    // ASSERT
    assert.equal(result, 1, "Doesn't get registered as an authorized caller");
    assert.equal(eventEmitted, true, "ContractAuthorized Event is not emmited");
  });

  it("register an airline in Flight Surety Data", async () => {
    // ARRANGE
    let newAirline = accounts[5];

    // ACT
    try {
      await config.flightSuretyData.setOperatingStatus(true);
      await config.flightSuretyData._registerAirline(
        newAirline,
        "New airline",
        {
          from: accounts[1],
        }
      );
    } catch (e) {}

    let result = await config.flightSuretyData._isAirline.call(newAirline);

    // ASSERT
    assert.isTrue(
      result,
      "The airline doesn't get registered with the account number"
    );
  });

  it("can verify that _registerAirline() checks if an airline is already registered and reverts if so", async () => {
    // ARRANGE
    let existingAirline = accounts[2];
    let isReverted = false;

    // ACT
    try {
      await config.flightSuretyData.setOperatingStatus(true);
      await config.flightSuretyData._registerAirline(
        existingAirline,
        "New airline",
        {
          from: accounts[1],
        }
      );
      await config.flightSuretyData._registerAirline(
        existingAirline,
        "New airline",
        {
          from: accounts[1],
        }
      );
    } catch (e) {
      isReverted = true;
    }

    // ASSERT
    assert.isTrue(
      isReverted,
      "registerAirline() unable to verify that an airline is already reigstered"
    );
  });

  it("can query the insurance using the beneficiary address and return the correct the payout amount and the flight address", async () => {
    // ARRANGE
    let beneficiary = accounts[2];
    let flightAddress = accounts[3];
    let insurance;
    let eventEmitted = false;
    let insuranceValue = new BigNumber(web3.utils.toWei("1", "ether"));

    // ACT
    try {
      await config.flightSuretyData.buy(beneficiary, flightAddress, {
        value: insuranceValue,
        gasPrice: 0,
      });
      insurance = await config.flightSuretyData.insuranceQuery.call(
        beneficiary
      );
    } catch (e) {
      throw new Error(e);
    }

    await config.flightSuretyData.contract.events.InsuranceBought(function () {
      eventEmitted = true;
    });

    const converted = web3.utils.fromWei(insurance[1], "ether");

    // ASSERT
    assert.equal(
      insurance[0],
      flightAddress,
      "The insurance flightAddress is not accurate"
    );
    assert.equal(converted, 1, "The insurance payout amount is not accurate");
    assert.isTrue(eventEmitted, "The event InsuranceBought is not emitted");
  });

  it("reverts when the insurance query fails", async () => {
    // ARRANGE
    let beneficiary = accounts[5];
    let isReverted = false;

    // ACT
    try {
      await config.flightSuretyData.insuranceQuery.call(beneficiary);
    } catch {
      isReverted = true;
    }

    // ASSERT
    assert.isTrue(
      isReverted,
      "The insuranceQuery function is not reverted even though the insurance doesn't exist"
    );
  });

  it("can credit the insuree and query for the balance with the beneficiary address", async () => {
    // ARRANGE
    let beneficiary = accounts[7];
    let flightAddress = accounts[9];
    let eventEmitted = false;
    let insuranceValue = new BigNumber(web3.utils.toWei("1", "ether"));

    // ACT
    await config.flightSuretyData.setOperatingStatus(true);
    await config.flightSuretyData.buy(beneficiary, flightAddress, {
      value: insuranceValue,
    });
    await config.flightSuretyData.creditInsurees(beneficiary);
    const result = await config.flightSuretyData.pendingCreditQuery(
      beneficiary
    );

    await config.flightSuretyData.contract.events.CreditIssuedToInsuree(
      function () {
        eventEmitted = true;
      }
    );

    let convertedResult = new BigNumber(web3.utils.fromWei(result, "ether"));
    //   let convertedResult = new BigNumber(web3.utils.fromWei(result, "ether"));

    // ASSERT
    assert.equal(
      convertedResult,
      1.5,
      "The insurance payout amount is not accurate"
    );
    assert.isTrue(
      eventEmitted,
      "The CreditIssuedToInsuree event is not emitted"
    );
  });

  it("buy() is reverted when msg.value is 0, creditInsurees() is reverted when the balance in insurance[beneficiary].amount is 0", async () => {
    // ARRANGE
    let beneficiary = accounts[2];
    let flightAddress = accounts[9];
    let isReverted = false;

    // ACT
    try {
      await config.flightSuretyData.buy(beneficiary, flightAddress, {
        value: 0,
      });
      await config.flightSuretyData.creditInsurees(beneficiary);
    } catch {
      isReverted = true;
    }

    assert.isTrue(
      isReverted,
      "creditInsurees() is not reverted even though insurance[beneficiary].amount is 0"
    );
  });

  it("reverts when the amount of balance in the pending credit is 0", async () => {
    // ARRANGE
    let beneficiary = accounts[5];
    let isReverted = false;

    // ACT
    try {
      await config.flightSuretyData.creditInsurees(beneficiary);
    } catch {
      isReverted = true;
    }

    // ASSERT
    assert.isTrue(
      isReverted,
      "creditInsurees() is not reverted even though the person is not insured"
    );
  });

  it("can pay the payout from the pending credit to the proper beneficiary", async () => {
    // ARRANGE
    let beneficiary = accounts[2];
    let flightAddress = accounts[4];
    let initialBalance;
    let postBalance;
    let eventEmitted = false;
    let insuranceValue = new BigNumber(web3.utils.toWei("1", "ether"));

    // ACT
    try {
      initialBalance = web3.utils.fromWei(
        await web3.eth.getBalance(beneficiary),
        "ether"
      );
    } catch (e) {
      throw new Error(e);
    }

    await config.flightSuretyData.setOperatingStatus(true);
    await config.flightSuretyData.buy(beneficiary, flightAddress, {
      value: insuranceValue,
      gasPrice: 0,
    });
    await config.flightSuretyData.creditInsurees(beneficiary);
    const result = await config.flightSuretyData.pendingCreditQuery(
      beneficiary
    );

    await config.flightSuretyData.pay({
      from: beneficiary,
      gasPrice: 0,
    });
    await config.flightSuretyData.contract.events.InsurancePayoutPaid(
      function () {
        eventEmitted = true;
      }
    );

    try {
      postBalance = web3.utils.fromWei(
        await web3.eth.getBalance(beneficiary),
        "ether"
      );
    } catch (e) {
      throw new Error(e);
    }

    let resultConverted = new BigNumber(web3.utils.fromWei(result, "ether"));
    assert.equal(
      postBalance - initialBalance,
      resultConverted,
      "The insurance payout failed"
    );
    assert.isTrue(eventEmitted, "The event InsurancePayoutPaid is not emitted");
  });

  it("can provide funds to the insurance by the airlines", async () => {
    let airline = accounts[2];
    let initialFund = new BigNumber(web3.utils.toWei("10", "ether"));
    let eventEmitted = false;
    await config.flightSuretyData.fund(airline, initialFund);
    const retrievedFund = await config.flightSuretyData._checkFunds(airline);

    config.flightSuretyData.contract.events.FundedByAirline(function () {
      eventEmitted = true;
    });
    const convertedRetrievedFund = web3.utils.fromWei(retrievedFund, "ether");

    // ASSERT
    assert.isTrue(eventEmitted, "The event FundedByAirline is not emitted");
    assert.equal(
      convertedRetrievedFund,
      10,
      "The fund is not properly provided"
    );
  });

  it("reverts when airline pays the amount other than 10 ether", async () => {
    let airline = accounts[7];
    let initialFund = new BigNumber(web3.utils.toWei("1", "ether"));
    let isReverted = false;
    try {
      await config.flightSuretyData.fund(airline, initialFund, {
        gasPrice: 0,
      });
    } catch {
      isReverted = true;
    }

    assert.isTrue(
      isReverted,
      "The fund() allows an airline to pay the amount other than 10 ether"
    );
  });

  it("reverts when the airline tries to doublepay", async () => {
    let airline = accounts[8];
    let initialFund = new BigNumber(web3.utils.toWei("10", "ether"));
    let isReverted = false;
    await config.flightSuretyData.fund(airline, initialFund, {
      gasPrice: 0,
    });
    try {
      await config.flightSuretyData.fund({
        from: airline,
        value: initialFund,
        gasPrice: 0,
      });
    } catch {
      isReverted = true;
    }

    assert.isTrue(isReverted, "The fund() allows an airline to pay twice");
  });
});
