//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Raffle} from "../src/Raffle.sol";
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId,) = createSubscription.createSubscription(config.vrfCoordinator, config.account);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.account ,config.subscriptionId, config.vrfCoordinator, config.link);
        }
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );

        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(config.account ,address(raffle), config.vrfCoordinator, config.subscriptionId);
        return (raffle, helperConfig);
    }
}
