//SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "./HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function CreateSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getConfig().account;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator,account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator , address account) public returns (uint256, address) {
        console.log("Creating subscription on Chain");
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription is ", subId);
        return (subId, vrfCoordinator);
    }

    function run() public {
        CreateSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstant {
    uint256 constant FUND_AMOUNT = 10 ether;

    function run() public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getConfig().account;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(account,subscriptionId, vrfCoordinator, linkToken);
    }

    function fundSubscription(address account, uint256 subscriptionId, address vrfCoordinator, address linkToken) public {
        console.log("Funding subscription on Chain");
        if (block.chainid == LOCAL_CHAIN_ID) {
            console.log("This is a local chain");
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log("This is not a local chain");
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() public {
        address MostRecentContract = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(MostRecentContract);
    }

    function addConsumerUsingConfig(address MostRecentContract) public {
        HelperConfig helperConfig = new HelperConfig();
        address account = helperConfig.getConfig().account;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        addConsumer(account, MostRecentContract, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address account, address MostRecentContract, address vrfCoordinator, uint256 subscriptionId) public {
        console.log("Adding consumer on Chain");

        console.log("This is a chain ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, MostRecentContract);
        vm.stopBroadcast();
    }
}
