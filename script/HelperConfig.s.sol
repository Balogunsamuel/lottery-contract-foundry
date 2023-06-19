// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    //if we are on a local chain deploy on mocks
    //Otherwise grab the existing chain on the codebase
    NetworkConfig public activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint64 public constant BASE_FEE = 0.25 ether; //0.25 LINK
    uint96 constant GAS_PRICE_LINK = 1e9; // 1gwei LINK

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 intervals;
        address vrfCooridnator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        /* uint256 lastTimeStamp;
        uint256 raffleState; */
        address link;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getEthMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                intervals: 30,
                vrfCooridnator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 2909,
                callbackGasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // address of sepolia
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getEthMainnetConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory ethonfig = NetworkConfig({
            entranceFee: 0.01 ether,
            intervals: 30,
            vrfCooridnator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
            gasLane: 0x9fe0eebf5e446e3c998ec9bb19951541aee00bb90ea201ae456421a2ded86805,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            deployerKey: vm.envUint("PRIVATE_KEY") // key of sepolia env
        });
        return ethonfig;
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        // price of feed address
        if (activeNetworkConfig.vrfCooridnator != address(0)) {
            return activeNetworkConfig;
        }

        //1. Deploy the VRFCoordinatorV2Mock
        //2. Return the VRFCoordinatorV2Mock address

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );
        vm.stopBroadcast();
        LinkToken link = new LinkToken();

        NetworkConfig memory anvilConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            intervals: 30,
            vrfCooridnator: address(vrfCoordinatorV2Mock),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // our script will add this!
            callbackGasLimit: 500000, // 500,000 gas!
            link: address(link),
            deployerKey: DEFAULT_ANVIL_KEY
        });
        return anvilConfig;
    }
}
