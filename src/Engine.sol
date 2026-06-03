


/* 
Layout of Smart-Contract: (in theory and in practice here)
1. Version
2. Imports
3. Interfaces, Libraries, Contracts
4. Errors
5. Types
6. State Variables
7. Events
8. Modifiers
9. Funcitons
*/

/* 
Layout of functions: (in theory)
1. Constructor
2. Recive Function
3. Fallback function
4. Public
5. Private
6. View, Pure
*/

/* 
Layout of functions sections: (in practice here)
1. Constructor
2. Deposit
3. Mint Stablecoins
4. Collateral (Calculate, Redeem)
5. Burn Stablecoins
6. Health Factor
7. Liquidation
*/



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { ReentrancyGuardTransient } from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import { Stablecoin } from "./Stablecoin.sol";
import { Oracle } from "./libraries/Oracle.sol";


/**
 * @title Stablecoin Engine
 * @author kuzminklk (Daniil Kuzmin)
 * @notice Meant to be the core of the stablecoin system, governing minting, burning, collateral managment and liquidation mechanics
 *
 * — Stablecoin System Description —
 * Relative Stability: Anchored (Pegged) to USD
 * Stability Mechanism (Minting): Algorithmic
 * Collateral: Exogenous (wETH, wBTC)
 * System always should be overcollateralized
 * (Similar to DAI, if DAI had no gevernance, no fees, and only backed by wETH, wBTC colateral)
 */
contract Engine is ReentrancyGuardTransient {

	// — Errors —

	error Engine__AmountMustBeGreaterThanZero();
	error Engine__TokensMustMatchPriceFeeds();
	error Engine__TokenNotAllowed();
	error Engine__TransferFailed();
	error Engine__MintFailed();
	error Engine__OraclePriceIsStale();

	error Engine__HealthFactorIsOK();
	error Engine__BreaksLiquidationHealthFactorThreshold(uint256 healthFactor);
	error Engine__BreaksOvercollateralizationHealthFactorThreshold(uint256 healthFactor);

	// — Type —
	
	using Oracle for AggregatorV3Interface;

	// — State Variables —

	uint256 private constant PRECISION = 1e18;
	uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10; // Add 1e10 to 1e8 Price Feed precision to get 1e18 as common in Ethereum
	uint256 private constant OVERCOLLATERALIZATION_HEALTH_FACTOR_THRESHOLD = 20 * PRECISION / 10;
	uint256 private constant LIQUIDATION_HEALTH_FACTOR_THRESHOLD = 11 * PRECISION / 10;
	uint256 private constant MINIMAL_HEALTH_FACTOR_THRESHOLD = 1 * PRECISION;

	/*
	— Example of Health Factor —
	1. From Infinite to 2 — OK (Alice puts 2000$ of wETH, takes 500$ of Stablecoin)
	2. From 2 to 1.1 — Overcollaterization buffer, doesn't give the opportunity to mint additional Stablecoins
	3. From 1.1 to 1 — Liquidation buffer, User can be liquidated
	4. From 1 to 0 — Ideally, should be not possible; means that collateral lost value and doesn't be liquidated in time
	*/

	Stablecoin immutable private i_stablecoin;

	mapping(address token => address priceFeed) private s_tokenToPriceFeed; /// Allowed for collateral tokens
	mapping(address user => mapping(address token => uint256 amount)) private s_userToDeposit;
	mapping(address user => uint256 mintedStablecoinsAmount) private s_userToMintedStablecoins;

	address[] private s_collateralTokens;

	// — Events —

	event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
	event CollateralRedeemed(address indexed user, address indexed token, uint256 amount);

	// — Modifiers —

	modifier amountMoreThanZero(uint256 amount) {
		if (amount <= 0) {
			revert Engine__AmountMustBeGreaterThanZero();
		}
		_;
	}

	modifier allowedToken(address token) {
		if (s_tokenToPriceFeed[token] == address(0)) {
			revert Engine__TokenNotAllowed();
		}
		_;
	}


	// ——— Functions ———

	// — Constructor —

	/**
	 * @param tokens Addresses of acceptable ERC20 tokens for collateral
	 * @param priceFeeds Price Feeds for these tokens
	 * @param stablecoin ERC20 Stablecoin for this Engine to mint and burn
	 * @dev Tokens and Price Feeds arrays must be in the same order, so we can map token to it's price feed by index
	 */
	constructor(address[] memory tokens, address[] memory priceFeeds, Stablecoin stablecoin) {
		if (tokens.length != priceFeeds.length) {
			revert Engine__TokensMustMatchPriceFeeds();
		}

		for (uint256 i; i < tokens.length; i++) {
			s_tokenToPriceFeed[tokens[i]] = priceFeeds[i];
			s_collateralTokens.push(tokens[i]);
		}

		i_stablecoin = stablecoin;
	}

	// — Deposit —

	/**
	 * @notice Deposit collateral to the system
	 * @param token The address of the token to deposit as collateral
	 * @param amount The amount of tokens as collateral
	 * @dev Follows CEI pattern, have reentrancy guard
	 */
	function depositCollateral(address token, uint256 amount) public amountMoreThanZero(amount) allowedToken(token) nonReentrant() {
		// Effects
		s_userToDeposit[msg.sender][token] += amount;
		emit CollateralDeposited(msg.sender, token, amount);
		// Interaction
		bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
		if (!success) {
			revert Engine__TransferFailed();
		}
	}

	function depositCollateralAndMintStablecoins(address collateralToken, uint256 collateralAmount, uint256 stablecoinsAmount ) public {
		depositCollateral(collateralToken, collateralAmount);
		mintStablecoins(stablecoinsAmount);
	}

	// — Mint Stablecoins —
	
	/**
	 * @param amount The amount of tokens to mint
	 * @dev User must have two times more collateral for minting value (200% overcollateralization)
	 */
	function mintStablecoins(uint256 amount) public amountMoreThanZero(amount) nonReentrant() {
		s_userToMintedStablecoins[msg.sender] += amount;
		_checkOvercollateralizationHealthFactor(msg.sender);
		bool success = i_stablecoin.mint(msg.sender, amount);
		if (!success) {
			revert Engine__MintFailed();
		}
	}

	// — Collateral (Calculate, Redeem) —

	/**
	 * @notice Get total value of token amount in USD
	 * @dev Uses Chainlink Price Feeds
	 * @return total The total value of collateral in USD with 1e18 precision
	 */
	function getValueInUSD(address token, uint256 amount) public view returns (uint256) {
		AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[token]);
		if (priceFeed.checkPriceStaleness()) revert Engine__OraclePriceIsStale();
		( , int256 price, , , ) = priceFeed.latestRoundData(); // Returns price with 1e8 precision
		return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
	}

	function getCollateralTokens() public view returns(address[] memory) {
		return s_collateralTokens;
	}

	function getCollateralBalance(address user, address token) public view returns (uint256) {
		return s_userToDeposit[user][token];
	}

	/**
	 * @notice Get the total value of collateral for a user
	 * @return total The total value of collateral in USD with 1e18 precision
	 */
	function getCollateralValue(address user) public view returns (uint256 total) {
		for(uint256 i = 0; i < s_collateralTokens.length; i++) {
			address token = s_collateralTokens[i];
			uint256 amount = s_userToDeposit[user][token];
			total += getValueInUSD(token, amount);
		}
		return total;
	}

	function redeemCollateral(address token, uint256 amount) public amountMoreThanZero(amount) {
		_redeemCollateralFromTo(token, amount, msg.sender, msg.sender);
		_checkOvercollateralizationHealthFactor(msg.sender);
	}

	function _redeemCollateralFromTo(address token, uint256 amount, address from, address to) private amountMoreThanZero(amount) {
		s_userToDeposit[from][token] -= amount;
		emit CollateralRedeemed(from, token, amount);

		bool success = IERC20(token).transfer(to, amount);	
		if (!success) {
			revert Engine__TransferFailed();
		}
	}

	// — Burn Stablecoins —

	function burnStablecoins(uint256 amount) public amountMoreThanZero(amount) {
		_burnStablecoinsFromTo(amount, msg.sender, msg.sender);
	}

	function _burnStablecoinsFromTo(uint256 amount, address from, address to) private amountMoreThanZero(amount) {
		s_userToMintedStablecoins[to] -= amount;
		bool success = i_stablecoin.transferFrom(from, address(this), amount);
		if (!success) {
			revert Engine__TransferFailed();
		}
		i_stablecoin.burn(amount);
	}

	function burnStablecoinsAndRedeemCollateral(address collateralToken, uint256 collateralAmount, uint256 stablecoinsAmount ) public {
		burnStablecoins(stablecoinsAmount);
		redeemCollateral(collateralToken, collateralAmount);
	}

	// — Health Factor —

	function _getUserState(address user) private view returns(uint256 totalStablecoinsMinted, uint256 collateralValue /* In USD */) {
		totalStablecoinsMinted = s_userToMintedStablecoins[user];
		collateralValue = getCollateralValue(user);
	}

	/**
	 * @notice Health Factor shows how close user to liquidation. If it's under 1, user can get liquidated
	 * See example of mechanics in liquidation() documentation
	 */
	function getHealthFactor(address user) public view returns (uint256) {
		(uint256 totalStablecoinsMinted, uint256 collateralValue) = _getUserState(user);
		if (totalStablecoinsMinted == 0) {
			return type(uint256).max; // If user have no debt, we consider his health factor as infinite (max uint256 value)
		}
		return collateralValue * PRECISION / totalStablecoinsMinted;
	}

	/**
	 * @notice Reverts if Health Factor breaks OVERCOLLATERALIZATION_HEALTH_FACTOR_THRESHOLD
	 */
	function _checkOvercollateralizationHealthFactor(address user) private view {
		uint256 healthFactor = getHealthFactor(user);
		if (healthFactor < OVERCOLLATERALIZATION_HEALTH_FACTOR_THRESHOLD) {
			revert Engine__BreaksOvercollateralizationHealthFactorThreshold(healthFactor);
		}
	}

	/**
	 * @notice Reverts if Health Factor breaks LIQUIDATION_HEALTH_FACTOR_THRESHOLD
	 */
	function _checkLiquidationHealthFactor(address user) private view {
		uint256 healthFactor = getHealthFactor(user);
		if (healthFactor < LIQUIDATION_HEALTH_FACTOR_THRESHOLD) {
			revert Engine__BreaksLiquidationHealthFactorThreshold(healthFactor);
		}
	}

	// — Liquidation —

	/**
	 * — Liquidation example —
	 * 1. Alice put 100$ of wETH as collateral and take 50$ of Stablecoin (*2 overcollateralization)
	 * 2. ETH price goes down to 55$ and happens Alice liqudation (10% liqudation buffer)
	 * 3. Someone buys Alice wETH collateral (worth 55$) for 50$ of Stablecoin and grab extra 5$ as reward for liquidation
	 */
	function liqudate(address user, address token, uint256 amount) public amountMoreThanZero(amount) nonReentrant() {
		uint256 startingUserHealthFactor = getHealthFactor(user);
		if (startingUserHealthFactor > LIQUIDATION_HEALTH_FACTOR_THRESHOLD) {
			revert Engine__HealthFactorIsOK();
		}

		uint256 availableTokensForLiquidation = s_userToDeposit[user][token];
		uint256 tokensValueInUSD = getValueInUSD(token, amount);

		// TODO: REVIEW THIS PART
		/*
		— Logic —
		1. Take Stablecoins from sender and burn, substract debt from taken user
		2. Redeem collateral from user to sender
		3. User have no debt and no collateral, but have his Stablecoins
		4. Sender lost his stablecoins but get tokens for 110% USD value of them

		— Issues —
		? Sender lost his Stablecoins but don't lost his debt → Sender have Health Factor Check
		*/
		_burnStablecoinsFromTo(tokensValueInUSD, msg.sender, user);
		_redeemCollateralFromTo(token, amount, user, msg.sender);

		uint256 senderHealthFactor = getHealthFactor(msg.sender);
		if (senderHealthFactor <= LIQUIDATION_HEALTH_FACTOR_THRESHOLD) {
			revert Engine__BreaksLiquidationHealthFactorThreshold(senderHealthFactor);
		}
	}

}