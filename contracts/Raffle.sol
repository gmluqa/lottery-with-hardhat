// Raffle

// Enter Raffle, pay fixed amount

// Pick random winner

// Winner to be selected every x mins, automated by keepers

// Randomness -> chainlinkVRF, execution -> chainlinkKeepers

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

error Raffle__NotEnoughEth();
error Raffle__TranferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/** @title Raffle Contract
 *   @author gmluqa
 *   @notice Contract for implementing automated decentralized raffle
 *   @dev implements CL keepers and CL VRF
 */

// Importing the chainlinkVRF consumer base + V2Interface, so that our contract can become VRFable
// https://docs.chain.link/docs/get-a-random-number/ Very useful to read alongside with docs
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";

// We interface with VRFConsumerBaseV2 (note, it's actually an abstract contract because at least one function is defined)
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type variables */
    enum RaffleState {
        OPEN,
        CALCULATING
    } // uint256 0 = open, 1 = calculating

    /* State variables*/
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // See constructor, Interface ABI encapsulates vrfCoordinator address, is of type vrfv2interface
    bytes32 private immutable i_keyHash;
    uint256 private i_entranceFee;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    // Lottery variables
    address private s_winner;
    address payable[] private s_players; // Not only is it an address array, but it also needs to be payable in order for any address in the array to receive funds
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    // Event uses convention of CapsCase, inverted name from function event derives from
    // Event logs aren't stored in storage, but are linked to a contract/address
    // Useful for connecting web2 -> web3, emitting events, it outputs transactionLogs
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */
    // The VRFConsumerBaseV2() is basically fulfilling the constructor of the interface, takes in the param of address vrf... and populates it
    constructor(
        bytes32 keyHash,
        address vrfCoordinatorV2, // contract, will have to deploy mock for local test
        uint256 entranceFee,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        // https://www.tutorialspoint.com/solidity/solidity_constructors.htm initing parent objects
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2); // Address gets typecasted as vrfcoordv2 interface, read state var vrfcoodinator
        i_entranceFee = entranceFee; // // https://eth-converter.com/ min price is 0.01 eth, converted to WEI
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN; // Uses enum
        s_lastTimeStamp = block.timestamp; // block.timestamp is eth native function, returns block
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEth();
        }
        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle__NotOpen();
        }
        // Need to typecase msg.sender, else code gives error
        s_players.push(payable(msg.sender));
        //Calls event, and fills in params
        emit RaffleEnter(msg.sender);
    }

    /**
     *@dev This is the function that the chainlink keeper nodes call
     * CL nodes look for upkeepneeded to return true
     * 1. Time interval passes
     * 2. Lottery needs at least 1 player and some eth
     * 3. Our keeper subscription is funded with link
     * 4. Lottery needs to be OPEN enum
     */
    // calldata can be better than memory if only needed to define once

    // https://docs.chain.link/docs/chainlink-keepers/compatible-contracts/#example-contract
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance); // Don't need to declare as bool since we did it in func
    }

    // external are cheaper than public, use external only when func is gonna be called from outside, but never from the same contract
    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (upkeepNeeded == false) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // Request rand rumb
        // Do something with rand numb
        // 2 tx process
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords( // requestId will be an event we emit
            // All vars here
            i_keyHash, // Specific key hash determines gas limit
            i_subscriptionId, // Is the ID for the subscription account
            REQUEST_CONFIRMATIONS, //How many confs we need
            i_callbackGasLimit, // How much gas the function will use max, blocks any operation above gas cost
            NUM_WORDS // How many random numbers we want (words is CS term for number)
        );
        emit RequestedRaffleWinner(requestId);
    }

    // internal because only gets called from within contract
    // Overriding interface function with customized funcs
    function fulfillRandomWords(
        uint256, /*requestId*/ // We still need to take the type identifier, but since we don't use it, we comment the variable out
        uint256[] memory randomWords
    ) internal override {
        // size of s_players array
        // Random number of size s_players array - 1 (since it starts at 0)
        // Can use (randomNumber % s_playersarray.length) and we get a number from 0-9
        uint256 indexOfWinner = randomWords[0] % s_players.length; // We use randomWords"[0]" because it's an array and there's only 1 random word, indexed at 0
        address payable winner = s_players[indexOfWinner];
        s_winner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // Reset array to 0 element inside
        s_lastTimeStamp = block.timestamp;
        (
            bool success, /*bytes memory dataReturned*/

        ) = winner.call{value: address(this).balance}(""); // Call sending of funds from contract to the winners address, see lesson 4 for different types of transfers
        if (!success) {
            revert Raffle__TranferFailed();
        }
        emit WinnerPicked(winner);
    }

    /*view/pure funcs*/

    function getIndexedPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getWinner() public view returns (address) {
        return s_winner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    // pure instead of view since it's CONSTANT
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    // Pure for constant again
    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
