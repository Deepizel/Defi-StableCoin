// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
/*
* @title DSCEngine
* @author Victor Ekundayo

* The system is designed to be as minimal as possible, and have the tokens maintain a 1 token === $1.00 peg
* The stablecoin has the following props:
*- Exogeneous collateral
*-Dollar Pegged
*-Algorithmic stable
* our DSC system should always be overcollateralized. at no point should all the value of the collateral be less than the $$ value of the DSC tokens minted.
- it is similar to DAI if DAI had no governance, no fees, and was only backed by WETH and WBTC.

* @notice This contract is the core of the Decentralized Stable Coin System.
* @notice It is responsible for minting and burning DSC tokens, depositing and withdrawing collateral.
@notice It is losely based on the MakerDAO DSS system.
*/

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine is ReentrancyGuard {
    // ERRORS
    error DSCEngine__MustBeMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorIsBroken();
    error DSCEngine__HealthFactorIsNotBelowMinimum();
    error DSCEngine__TransferFailed();
    error DSCEngine__BurnFailed();
    error DSCEngine__HealthFactorNotImproved();
    // State varibles

    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRICE_FEED_PRECISION = 1e8;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //we need you to be 200% collateralized to avoid liquidation
    uint256 private constant PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means a %10 bonus for liquidating
    DecentralizedStableCoin private immutable I_DSC;

    mapping(address token => address priceFeed) private priceFeeds; // token => price feed
    mapping(address user => mapping(address token => uint256 amount)) private collateralDeposited; // user => token => amount
    mapping(address user => uint256 amountOfDscMinted) private amountOfDscMinted;
    address[] private collateralTokens;
    // address weth;
    // address wbtc;
    // EVENTS

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );
    event DscBurned(address indexed user, uint256 indexed tokenCollateralAddress, uint256 amount);
    // MODIFIERS

    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert DSCEngine__MustBeMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (priceFeeds[token] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    // Functions
    // constructor (
    //  address[] memory tokenAddresses,
    //  address[] memory priceFeedAddresses,
    //  address dscAddress
    //  ){
    //     if (tokenAddresses.length != priceFeedAddresses.length) {
    //         revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame();
    //     }
    //     for (uint256 i = 0; i < tokenAddresses.length; i++) {
    //         priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
    //         // add the token to the array of collateral tokens
    //         collateralTokens.push(tokenAddresses[i]);
    //     }
    //     I_DSC = DecentralizedStableCoin(dscAddress);
    // }

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame();
        }        
    

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            // add the token to the array of collateral tokens
            collateralTokens.push(tokenAddresses[i]);
        }

            I_DSC = DecentralizedStableCoin(dscAddress);
    }
    /**
     * @notice Deposit collateral and mint DSC tokens.
     * @param tokenCollateralAddress The address of the collateral token.
     * @param amountCollateral The amount of collateral to deposit.
     * @param amountDscToMint The amount of DSC to mint.
     * follows CEI pattern (Checks, Effects, Interactions) to enforce best practices against reentrancy attacks
     * this mints DSC tokens and deposits collateral in one transaction
     */

    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    )
        public
        moreThanZero(amountCollateral)
        moreThanZero(amountDscToMint)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice Deposit collateral and mint DSC tokens.
     * @param tokenCollateralAddress The address of the collateral token.
     * @param amountCollateral The amount of collateral to deposit.
     * follows CEI pattern (Checks, Effects, Interactions) to enforce best practices against reentrancy attacks
     *
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }
    /**
     * Redeem collateral and burn DSC tokens.
     * tokenCollateralAddress The address of the collateral token.
     * amountCollateral The amount of collateral to redeem.
     * amountDscToBurn The amount of DSC to burn.
     * follows CEI pattern (Checks, Effects, Interactions) to enforce best practices against reentrancy attacks
     *
     */

    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        public
    {
        // burn first to prevent reentrancy amd to maintain lesser balance of DSC tokens before transfering to the user
        burnDsc(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }
    /**
    //  * Redeem collateral and burn DSC tokens.
    //  * tokenCollateralAddress The address of the collateral token.
    //  * amountCollateral The amount of collateral to redeem.
    //  * amountDscToBurn The amount of DSC to burn.
     * follows CEI pattern (Checks, Effects, Interactions) to enforce best practices against reentrancy attacks
     *
     */

    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
        // check the health factor after the collateral is redeemed
        _revertIfHealthFactorIsBroken(msg.sender);
    }
    // do we need to check health factor here?

    function burnDsc(uint256 amountDscToBurn) public moreThanZero(amountDscToBurn) nonReentrant {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); //dont think this will hit so subject to audit
    }
    // check if the collateral value > DSC amount, run all checks

    /**
     * @notice Mint DSC tokens.
     * @param amountDsc The amount of DSC to mint.
     * @notice they must have more than the minimum threshhold
     * follows CEI pattern (Checks, Effects, Interactions) to enforce best practices against reentrancy attacks
     *
     */
    function mintDsc(uint256 amountDsc) public moreThanZero(amountDsc) nonReentrant {
        // I_DSC.mint(msg.sender, amountDsc);
        amountOfDscMinted[msg.sender] += amountDsc;

        // check if health factor is broken
        _revertIfHealthFactorIsBroken(msg.sender);
        bool success = I_DSC.mint(msg.sender, amountDsc);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }
    // we need to liquidate a user if their health factor is broken or too poor to cover their debt
    // pay people to liquidate other users
    // @param collateral The erc20 token address of the collateral token to liquidate
    // @param user The address of the user to liquidate, their health factor has to be below the minimum health factor
    // @param debtToCover The amount of debt to cover or burn to improve the stablecoin users health factor
    // @notice you can partially liqidate a user by burning some of their DSC to improve their health factor
    // @notice you will get a bonus for liquidating a user
    // this function working is based on the assumption that the system is over collaterized 200% or more

    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        isAllowedToken(collateral)
        nonReentrant
    {
        // check the users health factor
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsNotBelowMinimum();
        }
        // we want to reduce the dsc debt they have and burn it
        // we need to get the eth amount of the dsc owed
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // we also give them a 10% bonus for liquidating
        // we should sweep extra amount in to a treasury
        uint256 bonusColateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusColateral;
        _redeemCollateral(collateral, totalCollateralToRedeem, user, msg.sender);
        // we need to burn the dsc
        _burnDsc(debtToCover, user, msg.sender);
        // check the health factor after the collateral is redeemed
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        // check the health factor of the liquidator
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function healthFactor(address user) external view returns (uint256) {
        (uint256 totalDscMinted,) = _getAccountInformation(user);
        return _healthFactor(user);
    }

    // PRIVATE AND INTERNAL FUNCTIONS
    /**
     * @dev low level internal function, should not to be called unless _healthfactor is checked
     * @param amountDscToBurn The amount of DSC to burn.
     * @param onBehalfOf The address of the user to burn the DSC on behalf of, usually the liquidator or the user themselves.
     * @param dscFrom The address of the user to burn the DSC from, usually the liquidator or the user themselves.
     * @notice we're removing the dsc from the liquidator or in any case the user account and burning it 
     * @notice we're also transferring the dsc from the liquidator or in any case the user account to the contract
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        // basically we're removing the dsc from the liquidator or in any case the user account and burning it 
        amountOfDscMinted[onBehalfOf] -= amountDscToBurn;
        // we transfer from the liquidator to the contract here to reduce he number of tokens they have 
        bool success = I_DSC.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }

        I_DSC.burn(amountDscToBurn);
    }

    function _redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral, address from, address to)
        private
    {
        collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * returns how close to liquidation a uer is
     * if a user gets below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // get the total collateral value in Usd
        // get the total DSC value
        // return the health factor
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = _getAccountInformation(user);
        uint256 collateralAdjustedForThreshold = (totalCollateralValueInUsd * LIQUIDATION_THRESHOLD) / PRECISION;
        if (totalDscMinted == 0) {
            return type(uint256).max;
        }
        uint256 userHealthFactor = (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        return userHealthFactor;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // checks healthfactor to be sure they have enough collateral
        // Reverrt if healthfactor is less than 1
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorIsBroken();
        }
    }

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        totalDscMinted = amountOfDscMinted[user];
        totalCollateralValueInUsd = getAccountCollateralValue(user);
    }

    function _getUsdValue(address token, uint256 amount) public view returns (uint256) {
        address priceFeed = priceFeeds[token];
        require(priceFeed != address(0), "Invalid price feed");
        (, int256 price,,,) = AggregatorV3Interface(priceFeed).latestRoundData();
        return (uint256(price) * ADDITIONAL_FEED_PRECISION * amount) / PRICE_FEED_PRECISION;
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through each collateral token, get the amount thyve deposited and get the usd value
        // loop through collateral tokens, get the amount deposited, get the usd value, and add it to the total
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 amount = collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        // price of ETH(token)
        // $/ETH ETH ??
        // were bacically getting the usdAmountInwei and dividing by the Eth amount
        AggregatorV3Interface priceFeed = AggregatorV3Interface(priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // price has 8 decimal place so we multiply by 1e10 to get the perfect price
        return (usdAmountInWei * PRICE_FEED_PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }
    // helper function for tests
    function getAccountInformation(address user ) external view returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) {
        (totalDscMinted, totalCollateralValueInUsd) = _getAccountInformation(user);
        return (totalDscMinted, totalCollateralValueInUsd);
    }
}
