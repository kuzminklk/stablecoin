


/* 
Layout of test sections:
1. Constructor
2. Deposit
3. Mint Stablecoins
4. Collateral (Calculate, Redeem)
5. Burn Stablecoins
6. Health Factor
7. Liquidation
*/



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Engine } from "../../src/Engine.sol";
import { Stablecoin } from "../../src/Stablecoin.sol";
import { DeploySystem } from "../../script/DeploySystem.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

import { console, Test } from "forge-std/Test.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";


contract TestEngine is Test {

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
	}

	// — Constructor —

	address[] public tokensAddresses;
	address[] public priceFeedsAddresses;

	function testRevertsIfMismatchArraysLength() public {
		tokensAddresses.push(weth);
		priceFeedsAddresses.push(wethToUsdPriceFeed);
		priceFeedsAddresses.push(wbtcToUsdPriceFeed);
		vm.expectRevert(Engine.Engine__TokensMustMatchPriceFeeds.selector);
			new Engine(tokensAddresses, priceFeedsAddresses, stablecoinContract);
	}

	// — Deposit  —

	function testRevertsIfCollateralIsZero() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);

			vm.expectRevert(Engine.Engine__AmountMustBeGreaterThanZero.selector);
				engineContract.depositCollateral(weth, 0);
		vm.stopPrank();
	}

	function testDepositCollateral() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateral(weth, USER1_COLLATERAL_AMOUNT);
			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(address(engineContract)));
		vm.stopPrank();
	}

	function testDepositCollateralAndMintStablecoins() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateralAndMintStablecoins(weth, USER1_COLLATERAL_AMOUNT, USER1_MINTED_STABLECOINS);
			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(USER1_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
		vm.stopPrank();
	}

	// — Mint Stablecoins —

	function testMintStablecoins() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateral(weth, USER1_COLLATERAL_AMOUNT);
			engineContract.mintStablecoins(USER1_MINTED_STABLECOINS);
			assertEq(USER1_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
		vm.stopPrank();
	}

	// — Collateral (Calculate, Redeem) —

	function testGetValueInUSD() public {
		// Test logic: 10e18 * 2,000 (mock ETH price) = 20,000e18 
		uint256 actualValueInUSD = engineContract.getValueInUSD(weth, USER1_COLLATERAL_AMOUNT);
		uint256 expectedValueInUSD = 20000e18;
		assertEq(expectedValueInUSD, actualValueInUSD);
	}

	function testGetCollateralValue() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateral(weth, USER1_COLLATERAL_AMOUNT);
		vm.stopPrank();
		// Test logic: 10e18 * 2,000 (mock ETH price) = 20,000e18 
			uint256 collateralValue = engineContract.getCollateralValue(USER1);
		uint256 expectedCollateralValue = 20000e18;
		assertEq(expectedCollateralValue, collateralValue);
	}

	function testRedeemCollateral() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateralAndMintStablecoins(weth, USER1_COLLATERAL_AMOUNT, USER1_MINTED_STABLECOINS);

			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(USER1_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
			
			Stablecoin(stablecoinContract).approve(address(engineContract), USER1_MINTED_STABLECOINS);
			engineContract.burnStablecoins(USER1_MINTED_STABLECOINS);
			engineContract.redeemCollateral(weth, USER1_COLLATERAL_AMOUNT);

			assertEq(USER1_WETH_BALANCE, ERC20Mock(weth).balanceOf(address(USER1)));
			assertEq(0, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(0, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
		vm.stopPrank();

	}

	// — Burn Stablecoins —

	function testBurnStablecoins() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateralAndMintStablecoins(weth, USER1_COLLATERAL_AMOUNT, USER1_MINTED_STABLECOINS);

			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(USER1_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
			
			Stablecoin(stablecoinContract).approve(address(engineContract), USER1_MINTED_STABLECOINS);
			engineContract.burnStablecoins(USER1_MINTED_STABLECOINS);

			assertEq(0, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
		vm.stopPrank();
	}

	function testBurnStablecoinsAndRedeemCollateral() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateralAndMintStablecoins(weth, USER1_COLLATERAL_AMOUNT, USER1_MINTED_STABLECOINS);

			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(USER1_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
			
			Stablecoin(stablecoinContract).approve(address(engineContract), USER1_MINTED_STABLECOINS);
			engineContract.burnStablecoinsAndRedeemCollateral(weth, USER1_COLLATERAL_AMOUNT, USER1_MINTED_STABLECOINS);

			assertEq(USER1_WETH_BALANCE, ERC20Mock(weth).balanceOf(address(USER1)));
			assertEq(0, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(0, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
		vm.stopPrank();
	}

	// — Health Factor —

	function testGetHealthFactor() public {
		/* Test logic:
		Collateral is 10wETH (20,000$), value for minted Stablecoins is 5000$.
		Health factor 20,000 / (5,000) = 4000000000000000000 (1e18 precision) */
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateral(weth, USER1_COLLATERAL_AMOUNT);
			engineContract.mintStablecoins(USER1_MINTED_STABLECOINS);
			assertEq(engineContract.getHealthFactor(USER1), 4000000000000000000);
		vm.stopPrank();
	}

	function testCheckOvercollateralizationHealthFactor() public {
		uint256 BREAKING_HEALTH_FACTOR = 1333333333333333333; // 1.3 with 1e18 percise

		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateral(weth, USER1_COLLATERAL_AMOUNT);
			vm.expectRevert(abi.encodeWithSelector(Engine.Engine__BreaksOvercollateralizationHealthFactorThreshold.selector, BREAKING_HEALTH_FACTOR));
			engineContract.mintStablecoins(USER1_MINTED_STABLECOINS * 3);
		vm.stopPrank();
	} 

	// — Liquidation —

	function testLiquidation() public {
		vm.startPrank(USER1);
			ERC20Mock(weth).approve(address(engineContract), USER1_COLLATERAL_AMOUNT);
			engineContract.depositCollateralAndMintStablecoins(weth, USER1_COLLATERAL_AMOUNT, USER1_MINTED_STABLECOINS);

			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(address(engineContract)));
			assertEq(USER1_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER1)));
		vm.stopPrank();
			
		MockV3Aggregator(wethToUsdPriceFeed).updateAnswer(500e8);

		vm.startPrank(USER2);
			ERC20Mock(weth).approve(address(engineContract), USER2_HUGE_COLLATERAL_AMOUNT);
			engineContract.depositCollateralAndMintStablecoins(weth, USER2_HUGE_COLLATERAL_AMOUNT, USER2_MINTED_STABLECOINS);

			assertEq(USER2_MINTED_STABLECOINS, Stablecoin(stablecoinContract).balanceOf(address(USER2)));

			Stablecoin(stablecoinContract).approve(address(engineContract), USER2_MINTED_STABLECOINS);
			engineContract.liqudate(USER1, weth, USER1_COLLATERAL_AMOUNT);
			assertEq(USER1_COLLATERAL_AMOUNT, ERC20Mock(weth).balanceOf(USER2));
		vm.stopPrank();

	}

}