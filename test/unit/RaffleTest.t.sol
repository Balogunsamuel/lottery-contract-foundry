// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    //Events
    event EnteredRaffle(address indexed players);

    Raffle raffle;
    HelperConfig helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 intervals;
    address vrfCooridnator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);

        (
            entranceFee,
            intervals,
            vrfCooridnator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
    }

    function testRaffleInitializesInOpenState() public view {
        //                                Because RaffleState is an enum
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    ////////////////////////
    // Enter Raffle     ////
    ////////////////////////

    function testRaffleWithoutEnoughEth() public {
        //Arrange
        vm.prank(PLAYER);
        //Act /Asset
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleIsCalculatingWinner() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testPlayerIsAddedToThePlayerArray() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnterRaffleEventEmits() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    ////////////////////////
    // check Upkeep     ////
    ////////////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Asser t
        // assert that is not false with is true
        assert(upkeepNeeded == false);
        //OR
        //assert(upkeepNeeded == true);
    }

    function testcheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded == false);
    }

    //Write the following test
    /* function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervals - 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded == false);
    } */

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);
    }

    ////////////////////
    //PerformUpkeep  ///
    ////////////////////

    function testPeformUpkeepCanOnlyRunIfCheckUpIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);

        //Act /assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // Act /assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier playerEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + intervals + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testperformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        playerEnteredAndTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    /////////////////////////
    //fulfill randomWords////
    ////////////////////////

    function testFulfilRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public playerEnteredAndTimePassed skipFork {
        //Arragne
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCooridnator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    /* function testFulfilRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        playerEnteredAndTimePassed
    {
        //Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for (
            uint i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        // Act
        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // pretend to be the chainlink vrf to get random number  & pick winner
        VRFCoordinatorV2Mock(vrfCooridnator).fulfillRandomWords(
            uint256(requestId), // the vrf cast it as a uint256 and not a bytes
            address(raffle)
        );

        //Assert
        assert(uint256(raffle.getRaffleState()) == 0);
        // assert(raffle.getRecentWinner() != address(0));
        // assert(raffle.getLengthOfPlayersArray() == 0);
        // assert(previousTimeStamp < raffle.getLastTimeStamp());
        // assert(
        //     raffle.getRecentWinner().balance ==
        //         STARTING_PLAYER_BALANCE + prize - entranceFee
        // );
    } */

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        playerEnteredAndTimePassed
        skipFork
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfCooridnator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
