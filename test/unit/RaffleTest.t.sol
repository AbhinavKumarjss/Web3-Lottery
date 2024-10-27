//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "forge-std/CodeConstant.sol";
contract RaffleTest is Test ,CodeConstant{
    uint256 public constant STARTING_BALANCE = 10 ether;

    Raffle public raffle;
    HelperConfig public helperconfig;
    address public PLAYER = makeAddr("player");

    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperconfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperconfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        vm.deal(PLAYER, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnoughEth() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsWhenPlayerEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testRaffleEnteringEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhenRaffleIsClosed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOver.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }
    /*//////////////////////////////////////////////////////////////////////////
                                       CHECK UPKEEP
    ///////////////////////////////////////////////////////////////////////////*/

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upKeepNeeded);
    }
    /*//////////////////////////////////////////////////////////////////////////
                                    PERFORM UPKEEP
    ///////////////////////////////////////////////////////////////////////////*/

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 current_Balance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        current_Balance += entranceFee;
        numPlayers = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                current_Balance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }
    modifier skipfork(){
        if(block.chainid != LOCAL_CHAIN_ID){
            _;
        }
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEntered
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }
    /*//////////////////////////////////////////////////////////////////////////
                            FULLFILL RANDOM WORDS
    ///////////////////////////////////////////////////////////////////////////*/
    function testFullfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId)
        public
        raffleEntered
    {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    COMPLETE TEST
    ///////////////////////////////////////////////////////////////////////////*/
    function testFullfillRandomWordsPicksAWinnerAndResetsArrayAndSendsMoney() public raffleEntered{
        uint256 additionalEntrance = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for(uint256 i = startingIndex;i < startingIndex + additionalEntrance; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer,1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingWinnerBalance = expectedWinner.balance;

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrance + 1);
        console.log("Winner :",recentWinner);
        console.log("Expected Winner :",expectedWinner);
        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingWinnerBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
        }
}
