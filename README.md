# 💠 DeFi Stablecoin Protocol

A decentralized, crypto-collateralized **stablecoin** system designed to maintain a soft peg to **$1.00** through algorithmic balancing and on-chain data from **Chainlink oracles**.  
Built entirely with **Solidity** and tested using **Foundry**.

---

## ⚙️ Overview

The **DeFi Stablecoin Protocol** aims to provide a **trust-minimized**, **decentralized**, and **collateral-backed** stablecoin architecture.  
Unlike fiat-backed or custodial stablecoins, this system leverages **exogenous collateral (ETH, BTC)** and an **on-chain minting mechanism** to maintain stability.

---

## 🧩 Core Mechanisms

### 1. 🪙 Relative Stability — *Anchored to $1.00*
- The system maintains a soft peg to USD.  
- Uses **Chainlink Price Feeds** for real-time ETH/USD and BTC/USD data.  
- Includes an internal balancing function that adjusts collateral ratios and exchange logic to keep assets near the $1.00 equivalent.

### 2. ⚖️ Stability Mechanism — *Algorithmic Minting*
- Users can **mint new stablecoins** by locking sufficient collateral.  
- Minting logic enforces **over-collateralization** (e.g., 150%) to ensure solvency.  
- Built with a focus on **decentralization**, avoiding any centralized mint or redemption authority.

### 3. 🔐 Collateral — *Exogenous (Crypto-based)*
- Supported assets:  
  - **wETH** (Wrapped Ether)  
  - **wBTC** (Wrapped Bitcoin)  
- Future versions may integrate additional ERC-20 collateral types.

---

## 🧠 Architecture
- **Solidity Smart Contracts** — core protocol logic.  
- **Foundry** — development, testing, and deployment framework.  
- **Chainlink Oracles** — secure, tamper-proof data feeds for real-time asset pricing.

