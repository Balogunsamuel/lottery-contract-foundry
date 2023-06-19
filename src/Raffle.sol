// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @title A sample Raffle contract
/// @author Balogun Samuel
/// @notice This contract is a raffle contract
/// @dev Implements Chainlink VRFv2

contract Raffle is VRFConsumerBaseV2 {
    //Errors
    error Raffle__NotEnoughEthSent();
    error Raffle__Transferfailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffleState
    );

    //Type declarations
    // if the raffle is currently open or calculating previous winner
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    //State Variables
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of each period lotttery duration in seconds
    uint256 private immutable i_intervals;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    //Events
    event EnteredRaffle(address indexed players);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed num);

    constructor(
        uint256 entranceFee,
        uint256 intervals,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_intervals = intervals;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    // When is the winner supposed to be picked
    /**
     * @dev This function that the chainlink automation nodes call
     * to see if it's time to perform an upkeep.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs
     * 2. The raffle is in the OPEN state
     * 3. The contract has ETH (aka, players)
     * 4. (Implicit) The subscription is funded with LINK
     *
     */

    function checkUpKeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* peformData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_intervals;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    //1. Get a random number
    //2. Use the random number to pick a player
    //3. Be automatically called when time has passed
    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_intervals) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        emit RequestedRaffleWinner(requestId);
    }

    //Checks, Effects, Interactions
    //Checks - require statements
    //Effects - declarations and variables(our contract)
    //Interactions- (other contract)
    function fulfillRandomWords(
        uint256 /* _requestId */,
        uint256[] memory _randomWords
    ) internal override {
        //modulo %, the reminder betwen two numbers divided i.e 10 % 8 =2
        // so the randowWords % total number of players = the answer will determine the winner, indexed in the s_players array
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        emit PickedWinner(winner);

        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool sucesss, ) = winner.call{value: address(this).balance}("   ");
        if (!sucesss) {
            revert Raffle__Transferfailed();
        }
    }

    // Getter functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayersArray() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }
}
