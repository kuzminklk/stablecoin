


/*
— Invarians Of The System —
1. Total supply of Stablecoin should be less than value of collateral * 2 (if price doesn't change)
*/



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Engine } from "../../src/Engine.sol";
import { Stablecoin } from "../../src/Stablecoin.sol";
import { DeploySystem } from "../../script/DeploySystem.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { Handler } from "./Handler.t.sol";

import { console, Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";


contract Invariant is StdInvariant, Test {
	uint256 public constant USER1_WETH_BALANCE = 100 ether; // Equal 100 wETH
	uint256 public constant USER1_COLLATERAL_AMOUNT = 10 ether; // Equal 10 wETH or 20,000$ (in mock price)
	uint256 public constant USER1_MINTED_STABLECOINS = 5000e18; // Equal 5,000$
	// Expected health factor for User is 4 (woth 1e18 percision)
	address public USER1 = makeAddr("USER1");

	uint256 public constant USER2_WETH_BALANCE = 100 ether; // Equal 100 wETH
	uint256 public constant USER2_COLLATERAL_AMOUNT = 10 ether; // Equal 10 wETH or 20,000$ (in mock price)
	uint256 public constant USER2_HUGE_COLLATERAL_AMOUNT = 100 ether; // Equal 10 wETH or 20,000$ (in mock price)
	uint256 public constant USER2_MINTED_STABLECOINS = 5000e18; // Equal 5,000$
	// Expected health factor for User is 4 (woth 1e18 percision)
	address public USER2 = makeAddr("USER2");

	DeploySystem public deployer;
	HelperConfig public config;
	Engine public engineContract;
	Stablecoin public stablecoinContract;

	address wethToUsdPriceFeed;
	address wbtcToUsdPriceFeed;
	address weth;
	address wbtc;

	function setUp() public {
		deployer = new DeploySystem();
		(stablecoinContract, engineContract, config) = deployer.run();
		(wethToUsdPriceFeed, wbtcToUsdPriceFeed, weth, wbtc) = config.activeNetworkConfig();

		ERC20Mock(weth).mint(USER1, USER1_WETH_BALANCE);
		ERC20Mock(weth).mint(USER2, USER2_WETH_BALANCE);

		Handler handler = new Handler(stablecoinContract, engineContract);
		targetContract(address(handler));
	}

	function invariant_systemOvercollateralized() public view {
		uint256 stablecoinsTotalSupply = stablecoinContract.totalSupply();
		uint256 totalDepositedWETH = IERC20(weth).balanceOf(address(engineContract));
		uint256 wethValue = engineContract.getValueInUSD(weth, totalDepositedWETH);

		assert(wethValue >= stablecoinsTotalSupply * 2);
	}

}