//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
abstract contract CodeConstant {
    uint96 constant MOCK_BASE_FEE = 0.25 ether;
    uint96 constant MOCK_GAS_PRICE_LINK = 1e9;
    uint256 constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, CodeConstant {
    error HELPERCONFIG__INVALID_CHAIN_ID();
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[LOCAL_CHAIN_ID] = getLocalConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public view returns (NetworkConfig memory) {
        if (networkConfig[chainId].vrfCoordinator != address(0)) {
            return networkConfig[chainId];
        } else {
            revert HELPERCONFIG__INVALID_CHAIN_ID();
        }
    }
    function getConfig() public view returns (NetworkConfig memory) {
        console.log("chainId- ", block.chainid);
        return getConfigByChainId(block.chainid);
    }
    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.001 ether,
                interval: 30,
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Sepolia VRFCoordinator address
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Sepolia gas lane
                callbackGasLimit: 500000,
                subscriptionId: 0
            });
    }
    function getLocalConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return networkConfig[LOCAL_CHAIN_ID];
        } else {
            vm.startBroadcast();
            VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE_LINK
            );
            vm.stopBroadcast();
            localNetworkConfig = NetworkConfig({
                entranceFee: 0.001 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinator),
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                subscriptionId: 0
            });
            return localNetworkConfig;
        }
    }
}
