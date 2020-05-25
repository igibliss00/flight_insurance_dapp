// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0 <0.7.0;

import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";


contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false

    struct Airline {
        string name;
        bool isFunded; // Initial funding for the insurance
        bool isRegistered; // Either one of the initial 4 airlines or have been voted in
    }

    struct Insurance {
        address flight;
        uint256 amount; // insurance payment
        bool isValue; // checks for the existence of the insurance
    }

    address[] multiSig = new address[](0);
    address[] fundedAirlines = new address[](0);

    mapping(address => Airline) public airlines;
    mapping(address => uint8) authorizedCaller; // contract address => 1
    mapping(address => Insurance) public insurance; // beneficiary => Insurance
    mapping(address => uint256) public pendingCredit;
    mapping(address => uint256) public funds;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event ContractAuthorized(address addr);
    event ContractDeauthorized(address addr);
    event InsuranceBought(address flight, uint256 amount);
    event AirlineRegistered(string name, bool isFunded, bool isRegistered);
    event CreditIssuedToInsuree(address beneficiary, uint256 creditAmount);
    event InsurancePayoutPaid(address beneficiary, uint256 amount);
    event FundedByAirline(address airline, uint256 amount);

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier authorizedCallerExists(address addr) {
        require(
            authorizedCaller[addr] != 1,
            "Authorized caller already exists"
        );
        _;
    }

    modifier authorizedCallerDoesntExists(address addr) {
        require(
            authorizedCaller[addr] == 1,
            "The contract is not recognized as an authorized caller that already exists"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */

    function isOperational() public pure returns (bool) {
        return true;
        // return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    /**
     * @dev Registers an account to be an authorized caller to authorizedCaller mapping
     * @param addr The account address to be authorized
     */

    function authorizeCaller(address addr)
        external
        requireIsOperational
        requireContractOwner
        authorizedCallerExists(addr)
    {
        require(addr != address(0), "Must be a valid address");
        authorizedCaller[addr] = 1;
        emit ContractAuthorized(addr);
    }

    /**
     * @dev Deauthorizes a contract from the authorizedCaller mapping
     * @param addr The account address to be deauthorized
     */

    function deauthorizeCaller(address addr)
        external
        requireIsOperational
        requireContractOwner
        authorizedCallerDoesntExists(addr)
    {
        require(addr != address(0), "Must be a valid address");
        delete authorizedCaller[addr];
        emit ContractDeauthorized(addr);
    }

    /**
     * @dev Checks to see if an account is an authorized caller
     * @param addr The address to be checked as an authorized caller
     * @return bool Returns true if the account is an authorized caller, false otherwise
     */
    function isAuthorizedCaller(address addr) external view returns (bool) {
        require(addr != address(0), "Must be a valid address");
        return authorizedCaller[addr] == 1;
    }

    /**
     * @dev Checks to see is a certain account registered in the airlines mapping.
     *      Doesn't check to see if the account has funded the initial 10 ether
     * @param addr The address for the account to be checked
     * @return bool Returns true if the account exists, false if it doesn't.
     */

    function isAirline(address addr)
        external
        view
        requireIsOperational
        returns (bool)
    {
        require(addr != address(0), "The address must be valid");
        return airlines[addr].isRegistered;
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     * @param addr The address of the new airline to be registered
     * @param name The name of the new airline to be registered
     * @return bool
     */

    function _registerAirline(address addr, string memory name)
        public
        requireIsOperational
        returns (bool)
    {
        require(!airlines[addr].isRegistered, "Airline is already registered");

        // isFunded is only true after seeding the initial 10 ether
        // airlines[addr] = Airline(name, false, true);
        airlines[addr] = Airline({
            name: name,
            isFunded: false,
            isRegistered: true
        });

        multiSig.push(addr);
        emit AirlineRegistered(
            airlines[addr].name,
            airlines[addr].isFunded,
            airlines[addr].isRegistered
        );

        return true;
    }

    /**
     * @dev Get the number of
     *
     */
    function _getMultiSigLength() public view returns (uint256) {
        return multiSig.length;
    }

    /**
     * @dev Buy insurance for a flight
     * @param beneficiary The person to receive the insurance payout
     * @param flight The flight address
     */

    function buy(address beneficiary, address flight)
        external
        payable
        requireIsOperational
    {
        require(beneficiary != address(0), "Not a valid address");
        require(
            msg.value > 0,
            "The insurance has to be purchased for more than 0 ether"
        );
        insurance[beneficiary] = Insurance({
            flight: flight,
            amount: msg.value,
            isValue: true
        });

        emit InsuranceBought(
            insurance[beneficiary].flight,
            insurance[beneficiary].amount
        );
    }

    /**
     * @dev Query the insurance detail
     * @param beneficiary The beneficiary address to search for the specific insurance
     * @return Returns beneficiary and the amount of the Insurance struct
     */

    function insuranceQuery(address beneficiary)
        external
        view
        requireIsOperational
        returns (address, uint256)
    {
        require(beneficiary != address(0), "Not a valid address");
        require(
            insurance[beneficiary].isValue == true,
            "The insurance for this airline doesn't exist"
        );
        Insurance memory i = insurance[beneficiary];
        return (i.flight, i.amount);
    }

    /**
     * @dev Credits payouts to insurees
     * @param beneficiary The address of the beneficiary of the pending credit
     */

    function creditInsurees(address beneficiary)
        external
        payable
        requireIsOperational
    {
        require(
            beneficiary != address(0),
            "The accounts are not valid addresses"
        );
        require(
            insurance[beneficiary].isValue == true,
            "The person is not insured"
        );

        require(insurance[beneficiary].amount > 0, "The payout has 0 balance");
        uint256 credit = insurance[beneficiary].amount;
        pendingCredit[beneficiary] = credit.mul(3).div(2);
        emit CreditIssuedToInsuree(beneficiary, pendingCredit[beneficiary]);
    }

    /**
     * @dev Queries for the pending query balance
     * @param beneficiary The address of he beneficiary for the pending credit
     * @return Returns the pending credit balance (uint256)
     */

    function pendingCreditQuery(address beneficiary)
        external
        view
        requireIsOperational
        returns (uint256)
    {
        require(beneficiary != address(0), "Not a valid address");
        require(
            insurance[beneficiary].isValue == true,
            "The person is not insured"
        );
        return pendingCredit[beneficiary];
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external payable requireIsOperational {
        require(msg.sender != address(0), "Not a valid address");
        require(
            insurance[msg.sender].isValue == true,
            "The caller is not insured"
        );
        require(
            pendingCredit[msg.sender] != 0,
            "The pending credit amount is 0"
        );
        uint256 payout = pendingCredit[msg.sender];
        pendingCredit[msg.sender] = 0;
        address(uint160(msg.sender)).transfer(payout);
        emit InsurancePayoutPaid(msg.sender, payout);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund(address addr, uint256 amount)
        external
        payable
        requireIsOperational
    {
        require(msg.value == 10 ether, "The fund must be 10 ether");
        require(
            airlines[addr].isFunded == false,
            "The airline has already funded"
        );

        funds[addr] = funds[addr].add(amount);
        airlines[addr].isFunded = true;
        fundedAirlines.push(addr);
        emit FundedByAirline(addr, amount);
    }

    /**
     * @dev Get the amount of funds from a specific airline
     * @return The amount of the funds
     */

    function _checkFunds(address addr)
        external
        view
        requireIsOperational
        returns (uint256)
    {
        require(
            airlines[addr].isFunded == true,
            "The airline hasn't provided any fund"
        );
        return funds[addr];
    }

    /**
     * @dev Get the number of airlines who has paid the 10 ether fund
     * @return Number of airlines
     */

    function _getNumOfFundedAirlines()
        external
        view
        requireIsOperational
        returns (address[] memory)
    {
        return fundedAirlines;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    // fallback() external payable {
    //     fund();
    // }
}
