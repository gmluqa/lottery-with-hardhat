// Raffle

// Enter Raffle, pay fixed amount

// Pick random winner

// Winner to be selected every x mins, automated by keepers

// Randomness -> chainlinkVRF, execution -> chainlinkKeepers

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

error Raffle__NotEnoughEth();

// Importing the chainlinkVRF consumer base, so that our contract can become VRFable
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

// We interface with VRFConsumerBaseV2 (note, it's actually an abstract contract because at least one function is defined)
contract Raffle is VRFConsumerBaseV2 {
    /* State variables*/
    // https://eth-converter.com/ min price is 0.01 eth, converted to WEI
    uint256 public constant MINIMUM_ETH = 10000000000000000;

    /* Events */
    // Event uses convention of CapsCase, inverted name from function event derives from
    // Event logs aren't stored in storage, but are linked to a contract/address
    // Useful for connecting web2 -> web3, emitting events, it outputs transactionLogs
    event RaffleEnter(address indexed player);

    // The VRFConsumerBaseV2() is basically fulfilling the constructor of the interface, takes in the param of address vrf... and populates it
    constructor(address vrfCoordinatorV2) VRFConsumerBaseV2(vrfCoordinatorV2) {}

    // Not only is it an address array, but it also needs to be payable in order for any address in the array to receive funds
    address payable[] private s_players;

    function enterRaffle() public payable {
        if (msg.value < MINIMUM_ETH) {
            revert Raffle__NotEnoughEth();
        }
        // Need to typecase msg.sender, else code gives error
        s_players.push(payable(msg.sender));
        //Calls event, and fills in params
        emit RaffleEnter(msg.sender);
    }

    // external are cheaper than public, use external only when func is gonna be called from outside, but never from the same contract
    function requestRandomWinner() external {
        // Request rand rumb
        // Do something with rand numb
        // 2 tx process
    }

    // internal because only gets called from within contract
    // Overriding interface function with customized funcs
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {}

    /*view/pure*/

    function getIndexedPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
