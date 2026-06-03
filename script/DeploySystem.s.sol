

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";

import { Stablecoin } from "../src/Stablecoin.sol";
import { Engine } from "../src/Engine.sol";
import { HelperConfig } from "../script/HelperConfig.s.sol";


contract DeploySystem is Script {
	address[] public tokensAddresses;
	address[] public priceFeedsAddresses;

	function run() external returns (Stablecoin, Engine, HelperConfig) {
		HelperConfig config = new HelperConfig();
		(address wethToUsdPriceFeed, address wbtcToUsdPriceFeed, address weth, address wbtc) = config.activeNetworkConfig();
		tokensAddresses = [weth, wbtc];
		priceFeedsAddresses = [wethToUsdPriceFeed, wbtcToUsdPriceFeed];

		vm.startBroadcast();
			Stablecoin StablecoinContract = new Stablecoin();

			Engine EngineContract = new Engine(tokensAddresses, priceFeedsAddresses, StablecoinContract);

			StablecoinContract.transferOwnership(address(EngineContract));
		vm.stopBroadcast();

		return (StablecoinContract, EngineContract, config);
	}
}
