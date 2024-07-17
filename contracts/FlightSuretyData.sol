pragma solidity >=0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    struct AirlineInfo{
        string name;
        address[] approvals;
        airlinestate state;
    }

    enum airlineState{
        Applied,
        Registered,
        Paid
    }

    struct InsuranceInfo{
        address passenger;
        uint256 value;
        insuranceState status;
    }

    enum insuranceState{
        Active,
        Inactive
    }

    mapping(address => AirlineInfo) private airlines;
    mapping(address => uint256) private airlineFunding;
    address[] airlinesArray;
    mapping(address => bool) private authorizedCallers;
    mapping(bytes32 => InsuranceInfo[]) private insurances;
    mapping(address => uint256) private payoutValue;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        airlines[contractOwner].state = airlineState.Paid;
        airlines[contractOwner].name = "Genesis airline";
        airlinesArray.push(contractOwner);
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
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
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
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizedCall(address contractAddress) external requireContractOwner requireIsOperational {
        authorizedCallers[contractAddress] = true;
    }

    function vote
                            (
                                address candidate,
                                address voter
                            )
                            external 
                            requireIsOperational
    {
        require(airlines[voter].state == airlineState.Paid, "This airline is not allowed to vote"); //requires the airlines state is Paid
        airlines[candidate].approvals.push(voter);
        if(airlines[candidate].approvals.length.mod(2) == 0){
            if (airlines[candidate].approvals.length >= airlinesArray.length.div(2)){ //check at least 50% of approvals
                airlines[candidate].state = airlineState.Registered;
            }
        }
        else{
            if (airlines[candidate].approvals.length > airlinesArray.length.div(2)){  //check at least 50% of approvals
                airlines[candidate].state = airlineState.Registered;
            } 
        }
    }
    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address _airline, string calldata _name   
                            )
                            external
                            pure
    {
        airlines[_airline].name = _name;
        if (airlinesArray.lenth <= 4){
            airlines[_airline].state = airlineState.Registered; // Register automatically if there are 4 or less airlines
        }
        else{
            airlines[_airline].state = airlineState.Applied;
        }
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (  
                                address _passenger,
                                bytes32 _flightKey                           
                            )
                            external
                            payable
    {
        require(msg.value <= 1, "Above maximum value");
        insurances[_flightKey].push(InsuranceInfo({
            passenger: _passenger,
            value: msg.value,
            status: insuranceState.Active
        }));
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    bytes32 _flightKey
                                )
                                external
                                pure
                                requireIsOperational()
    {
        for(uint256 i = 0; i < insurances[_flightKey].length; i++){ //iterates for insurances for the given flightkey
            if(insurances[_flightKey][i].status == insuranceState.Active){ //check if the insurance is active 
                insurances[_flightKey][i].status = insuranceState.Closed; //swich the insurance status to closed
                payoutValue[insurances[_flightKey][i].passenger].add(insurances[_flightKey][i].value.div(2).mul(3)); //calculate the amount to be paid x3 /2 = 1.5
            }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address payable _passenger
                            )
                            external
                            pure
                            requireIsOperational
    {
        uint256 amount = payoutValue[_passenger];
        payoutValue[_passenger] = 0;
        _passenger.transfer(amount);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
        airlineFunding[msg.sender].add(msg.value);
        if(airlineFunding[msg.sender] >= 10 ether){
            airlines[msg.sender].state = airlineState.Paid;
            airlinesArray.push(msg.sender);
        }
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

