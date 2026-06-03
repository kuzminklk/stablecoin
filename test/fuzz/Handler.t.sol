


/* Handler is narrow down the way we call fucntions */



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Engine } from "../../src/Engine.sol";
import { Stablecoin } from "../../src/Stablecoin.sol";
import { DeploySystem } from "../../script/DeploySystem.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";

import { console, Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";


contract Handler is Test {
	Engine public engineContract;
	Stablecoin public stablecoinContract;

	address wethToUsdPriceFeed;
	address wbtcToUsdPriceFeed;
	address weth;
	address wbtc;

	uint256 MAX_DEPOSIT_AMOUNT = type(uint128).max;

	constructor(Stablecoin _stablecoinContract, Engine _engineContract) {
		stablecoinContract = _stablecoinContract;
		engineContract = _engineContract;

		// TODO: IMPLEMENT MORE AGNOSTIC BEHAVIOR
		weth = engineContract.getCollateralTokens()[0];
		wbtc = engineContract.getCollateralTokens()[1];
	}

	function depositCollateral(uint256 collateralTokenSeed, uint256 collateralAmountSeed) public {
		address collateralToken = _getCollateralTokenFromSeed(collateralTokenSeed);
		uint256 boundedCollateralAmount = bound(collateralAmountSeed, 1, MAX_DEPOSIT_AMOUNT);
		vm.startPrank(msg.sender);
			ERC20Mock(collateralToken).mint(msg.sender, boundedCollateralAmount);
			ERC20Mock(collateralToken).approve(address(engineContract), boundedCollateralAmount);
			engineContract.depositCollateral(collateralToken, boundedCollateralAmount);
		vm.stopPrank();
	}

	function redeemCollateral(uint256 collateralTokenSeed, uint256 collateralAmountSeed) public {
		address collateralToken = _getCollateralTokenFromSeed(collateralTokenSeed);
		uint256 fullCollateralAmount = engineContract.getCollateralBalance(msg.sender, collateralToken);
		vm.assume(fullCollateralAmount != 0);
		uint256 boundedCollateralAmount = bound(collateralAmountSeed, 1, fullCollateralAmount);
		vm.startPrank(msg.sender);
			engineContract.redeemCollateral(collateralToken, boundedCollateralAmount);
		vm.stopPrank();
	}

	function mintStablecoins(uint256 amountSeed) public {
		address collateralToken = _getCollateralTokenFromSeed(amountSeed);
		uint256 fullCollateralAmount = engineContract.getCollateralBalance(msg.sender, collateralToken);
		vm.assume(fullCollateralAmount != 0);
		uint256 boundedCollateralAmount = bound(amountSeed, 1, fullCollateralAmount);
		uint256 mintAmount = boundedCollateralAmount / 2;
		vm.assume(mintAmount != 0);
		vm.startPrank(msg.sender);
			engineContract.mintStablecoins(mintAmount);
		vm.stopPrank();
	}

	function _getCollateralTokenFromSeed(uint256 collateralTokenSeed) private view returns (address) {
		/* if (collateralTokenSeed % 2 == 0) {
			return weth;
		} else {
			return wbtc;
		} */
		return weth;
	}
}