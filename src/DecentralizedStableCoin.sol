// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
/*
* @title Decentralized Stable Coin
* Stability Mechanism: Algorithmic (Decentralization)
* @author Victor Ekundayo
    collateral1: wETH wBTC (exogeneous)
    Relative Stability: Pegged to $
* This is the contract meant to be governed by DSCEngine. Its is the ERC20 implementation of our stablecoin system.

*/


contract DecentralizedStableCoin is ERC20Burnable {
    constructor() ERC20("Decentralized Stable Coin", "DSC") {
    }



}