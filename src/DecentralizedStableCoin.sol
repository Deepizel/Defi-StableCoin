// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/*
* @title Decentralized Stable Coin
* Stability Mechanism: Algorithmic (Decentralization)
* @author Victor Ekundayo
    collateral1: wETH wBTC (exogeneous)
    Relative Stability: Pegged to $
* This is the contract meant to be governed by DSCEngine. Its is the ERC20 implementation of our stablecoin system.

*/

contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("Decentralized Stable Coin", "DSC") Ownable(initialOwner) {}

    function burn(uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (amount > balance) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }
        if (amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        super.burn(amount);
    }

    function mint(address _to, uint256 amount) public onlyOwner returns (bool) {
        if (amount <= 0) {
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }
        if (_to == address(0)) {
            revert DecentralizedStableCoin__NotZeroAddress();
        }
        _mint(_to, amount);
        return true;
    }
}
