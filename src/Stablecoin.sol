


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


import { ERC20, ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";


/*
* @title Stablecoin Token ERC20 Implementation
* @autor kuzminklk (Daniil Kuzmin)
*
* — Contract Description — 
* ERC-20 implementation for stablecoin token. Meant to be governed by Engine smart-contract for buning and minting.
*
* — Stablecoin System Description —
* Relative Stability: Anchored (Pegged) to USD
* Stability Mechanism (Minting): Algorithmic
* Collateral: Exogenous (wETH, wBTC) → System always should be overcollateralized
* (Similar to DAI, if DAI had no gevernance, no fees, and only backed by wETH, wBTC colateral)
*/
contract Stablecoin is ERC20Burnable, Ownable {

	constructor() ERC20("Stablecoin", "STABLE") Ownable(msg.sender) {}

	function burn(uint256 _amount) public override onlyOwner {
		super.burn(_amount);
	} 

	function mint(address _to, uint256 _amount) external onlyOwner returns(bool) {
		_mint(_to, _amount);
		return true;
	}
}