// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (
            uint256 entranceFee,
            uint256 intervals,
            address vrfCooridnator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // create subscription from the interactions.s.sol when subscription is zero!
            CreateSubscription createSubscriptionNow = new CreateSubscription();
            subscriptionId = createSubscriptionNow.createSubscription(
                vrfCooridnator,
                deployerKey
            );

            FundSubscription fundSubscriptionNow = new FundSubscription();
            fundSubscriptionNow.fundSubscription(
                vrfCooridnator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            intervals,
            vrfCooridnator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumerNow = new AddConsumer();
        addConsumerNow.addCustomer(
            address(raffle),
            vrfCooridnator,
            subscriptionId,
            deployerKey
        );

        return (raffle, helperConfig);
    }
}
