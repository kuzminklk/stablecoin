

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import { Stablecoin } from "../src/Stablecoin.sol";
import { Engine } from "../src/Engine.sol";
import { MockV3Aggregator } from "../test/mocks/MockV3Aggregator.sol";


contract HelperConfig is Script {

	struct NetworkConfig {
		address wethToUsdPriceFeed;
		address wbtcToUsdPriceFeed;
		address weth;
		address wbtc;
	}

	uint8 public constant DECIMALS = 8;
	uint256 public constant USD_TO_ETH_PRICE = 2000 * 10 ** DECIMALS; 
	uint256 public constant USD_TO_BTC_PRICE = 60000 * 10 ** DECIMALS; 

	NetworkConfig public activeNetworkConfig; 

	constructor() {
		if (block.chainid == 	11155111) {
			activeNetworkConfig = getEhtereumSepoliaConfig();
		} else if (block.chainid == 31337) {
			activeNetworkConfig = getOrCreateAnvilConfig();
		}
	}

	// TODO: REVIEW WBTC DECIMALS
	function getEhtereumSepoliaConfig() public pure returns (NetworkConfig memory) {
		return NetworkConfig({
			wethToUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
			wbtcToUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
			weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
			wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063
		});
	}

	function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
		if (activeNetworkConfig.wethToUsdPriceFeed != address(0)) {
			return activeNetworkConfig;
		}

		vm.startBroadcast();
			MockV3Aggregator wethToUsdPriceFeed = new MockV3Aggregator(DECIMALS, int256(USD_TO_ETH_PRICE));
			ERC20Mock weth = new ERC20Mock();

			MockV3Aggregator wbtcToUsdPriceFeed = new MockV3Aggregator(DECIMALS, int256(USD_TO_BTC_PRICE));
			ERC20Mock wbtc = new ERC20Mock();
		vm.stopBroadcast();

		return NetworkConfig({
			wethToUsdPriceFeed: address(wethToUsdPriceFeed),
			wbtcToUsdPriceFeed: address(wbtcToUsdPriceFeed),
			weth: address(weth),
			wbtc: address(wbtc)
		});
	}

	function run() external {
	}
}
