// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.6.0 <0.7.0;
// pragma solidity ^0.5.8;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/@openzeppelin/contracts/math/SafeMath.sol";

import "./FlightSuretyData.sol";


/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    uint8 constant AIRLINE_THRESHOLD = 4;
    uint256 constant MIN_REQ_DEPOSIT = 10 ether;
    FlightSuretyData flightSuretyData;
    address[] votedAirlines = new address[](0);

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

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
        // Modify to call data contract's status
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

    /**
     * @dev Modifier to check if the caller is authorized
     */
    modifier requireAuthorized() {
        require(
            flightSuretyData._isAuthorizedCaller(msg.sender) == true,
            "The caller is not authorized"
        );
        _;
    }

    /**
     * @dev Modifier that requires the airline to have made the 10 ether deposit to be able to register other airlines
     */
    modifier requireFundDeposited() {
        uint256 funds = flightSuretyData._checkFunds(msg.sender);
        require(
            funds >= MIN_REQ_DEPOSIT,
            "Must have deposited minimum 10 ether"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        // flightSuretyData = new FlightSuretyData();
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     * When operational mode is disabled, all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function getNumOfFundedAirlines()
        external
        view
        requireIsOperational
        returns (uint256)
    {
        address[] memory fundedAirlines = flightSuretyData
            ._getNumOfFundedAirlines();
        return fundedAirlines.length;
    }

    function authorizeCaller(address addr) public requireIsOperational {
        flightSuretyData._authorizeCaller(addr);
    }

    function deauthorizeCaller(address addr) public requireIsOperational {
        flightSuretyData._deauthorizeCaller(addr);
    }

    // /**
    //  * @dev Add an airline to the registration queue.
    //  * @param airline The address of the airline to be registered after the 4th initial airlines.
    //  * The first 4 will have to be authorized by the contract owner and will be registered using msg.sender.
    //  * The airlines starting from the 5th will be voted on by the first 4.
    //  * @param name The name of the airline to be registered to the Airline struct in FlightSuretyData. The first 4 have to register the name as well.
    //  * @return Returns the status of the registration with true or false.
    //  */

    // function registerAirline(address airline, string memory name)
    //     public
    //     requireIsOperational
    //     requireFundDeposited
    //     returns (bool)
    // {
    //     require(airline != address(0), "Must be a valid address");
    //     bool isSuccessful = false;
    //     bool isAuthorized = flightSuretyData._isAuthorizedCaller(msg.sender);
    //     if (isAuthorized) {
    //         isSuccessful = flightSuretyData._registerAirline(msg.sender, name);
    //         return isAuthorized;
    //     } else {
    //         return isAuthorized;
    //     }
    //     // return isSuccessful;
    // }

    // function test(address addr) public returns (bool) {
    //     flightSuretyData._authorizeCaller(addr);
    //     return flightSuretyData._isAuthorizedCaller(addr);
    // }

    // function test(address addr, string memory name) public returns (bool) {
    //     return flightSuretyData._registerAirline(addr, name);
    //     // return flightSuretyData.isOperational();
    // }

    function registerAirline(address airline, string memory name)
        public
        requireIsOperational
        requireFundDeposited
        requireAuthorized
        returns (bool)
    {
        require(airline != address(0), "Must be a valid address");
        bool isSuccessful = false;
        uint256 numOfRegisteredAirlines = flightSuretyData._getMultiSigLength();
        if (numOfRegisteredAirlines < AIRLINE_THRESHOLD) {
            isSuccessful = flightSuretyData._registerAirline(airline, name);
            return isSuccessful;
        } else {
            bool finalReg = false;
            votedAirlines.push(msg.sender);
            if (votedAirlines.length >= numOfRegisteredAirlines.div(2)) {
                finalReg = flightSuretyData._registerAirline(airline, name);
                return finalReg;
            } else {
                return finalReg;
            }
        }
    }

    /**
     * @dev Funds provided by the airlines
     */
    function airlineFunding() public payable requireIsOperational {
        flightSuretyData.fund(msg.sender, msg.value);
    }

    /**
     * @dev Checks whether the fund by the airline is properly loaded
     * @return The balance of the fund
     */
    function checkFunds() public view requireIsOperational returns (uint256) {
        uint256 amount = flightSuretyData._checkFunds(msg.sender);
        return amount;
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */

    function registerFlight() external pure {}

    /**
     * @dev Called after oracle has updated flight status
     *
     */

    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal pure {}

    // Generate a request for oracles to fetch flight information
    // function fetchFlightStatus(
    //     address airline,
    //     string memory flight,
    //     uint256 timestamp
    // ) public {
    //     uint8 index = getRandomIndex(msg.sender);

    //     // Generate a unique key for storing the request
    //     bytes32 key = keccak256(
    //         abi.encodePacked(index, airline, flight, timestamp)
    //     );
    //     oracleResponses[key] = ResponseInfo({
    //         requester: msg.sender,
    //         isOpen: true
    //     });

    //     emit OracleRequest(index, airline, flight, timestamp);
    // }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    // function registerOracle() external payable {
    //     // Require registration fee
    //     require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

    //     uint8[3] memory indexes = generateIndexes(msg.sender);

    //     oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    // }

    // function getMyIndexes() external view returns (uint8[3]) {
    //     require(
    //         oracles[msg.sender].isRegistered,
    //         "Not registered as an oracle"
    //     );

    //     return oracles[msg.sender].indexes;
    // }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    // function submitOracleResponse(
    //     uint8 index,
    //     address airline,
    //     string flight,
    //     uint256 timestamp,
    //     uint8 statusCode
    // ) external {
    //     require(
    //         (oracles[msg.sender].indexes[0] == index) ||
    //             (oracles[msg.sender].indexes[1] == index) ||
    //             (oracles[msg.sender].indexes[2] == index),
    //         "Index does not match oracle request"
    //     );

    //     bytes32 key = keccak256(
    //         abi.encodePacked(index, airline, flight, timestamp)
    //     );
    //     require(
    //         oracleResponses[key].isOpen,
    //         "Flight or timestamp do not match oracle request"
    //     );

    //     oracleResponses[key].responses[statusCode].push(msg.sender);

    //     // Information isn't considered verified until at least MIN_RESPONSES
    //     // oracles respond with the *** same *** information
    //     emit OracleReport(airline, flight, timestamp, statusCode);
    //     if (
    //         oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
    //     ) {
    //         emit FlightStatusInfo(airline, flight, timestamp, statusCode);

    //         // Handle flight status as appropriate
    //         processFlightStatus(airline, flight, timestamp, statusCode);
    //     }
    // }

    // function getFlightKey(
    //     address airline,
    //     string flight,
    //     uint256 timestamp
    // ) internal pure returns (bytes32) {
    //     return keccak256(abi.encodePacked(airline, flight, timestamp));
    // }

    // // Returns array of three non-duplicating integers from 0-9
    // function generateIndexes(address account) internal returns (uint8[3]) {
    //     uint8[3] memory indexes;
    //     indexes[0] = getRandomIndex(account);

    //     indexes[1] = indexes[0];
    //     while (indexes[1] == indexes[0]) {
    //         indexes[1] = getRandomIndex(account);
    //     }

    //     indexes[2] = indexes[1];
    //     while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
    //         indexes[2] = getRandomIndex(account);
    //     }

    //     return indexes;
    // }

    // // Returns array of three non-duplicating integers from 0-9
    // function getRandomIndex(address account) internal returns (uint8) {
    //     uint8 maxValue = 10;

    //     // Pseudo random number...the incrementing nonce adds variation
    //     uint8 random = uint8(
    //         uint256(
    //             keccak256(
    //                 abi.encodePacked(blockhash(block.number - nonce++), account)
    //             )
    //         ) % maxValue
    //     );

    //     if (nonce > 250) {
    //         nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
    //     }

    //     return random;
    // }

    // endregion
}

// contract FlightSuretyData {
//     function _authorizeCaller(address addr) external;

//     function _deauthorizeCaller(address addr) external;

//     function _isAuthorizedCaller(address addr) external returns (bool);

//     function _registerAirline(address addr, string memory name) public;

//     function _checkFunds(address addr) external view returns (uint256);
// }
