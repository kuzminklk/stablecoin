


/* 
Layout of Smart-Contract:
1. Version
2. Imports
3. Errors
4. Interfaces, Libraries, Contracts
5. Types
6. State Variables
7. Events
8. Modifiers
9. Funcitons
*/

/* 
Layout of functions:
1. Constructor
2. Recive Function
3. Fallback function
4. External
5. Public
6. Internal
7. Private
8. View, Pure
*/



// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


library Oracle {
	uint256 private constant TIMEOUT = 3 hours;  

	function checkPriceStaleness(AggregatorV3Interface priceFeed) public view returns (bool) {
		(uint80 roundId, int256 answer, uint256 staratedAt, uint256 updatedAt, uint80 answerInRound) = priceFeed.latestRoundData();
		uint256 secondsSince = block.timestamp - updatedAt;
		if (secondsSince > TIMEOUT) {
			return true;
		} else {
		return false;
		}
	}
}