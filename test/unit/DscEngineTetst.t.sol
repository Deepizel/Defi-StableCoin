// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployDsc} from "../../script/DeployDsc.s.sol";
import {ERC20Mock} from "../Mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    DeployDsc deployer;
    HelperConfig helperConfig;
    address weth;
    address ethUsdPriceFeed;
    address wbtc;
    address btcUsdPriceFeed;
    address public User = makeAddr("User");

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_COLLATERAL = 10 ether;
    uint256 public constant PRICE_PRECISION = 1e10;

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dsce, helperConfig) = deployer.run();
        // we might as well just have for weth, and ethPriceFeed to reduce lines of code
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(User, STARTING_COLLATERAL);
    }
    // COLLECTOR TEST ////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoseNotMatchPriceFeeds() public {
        // intentionally mismatch the length of the token addresses and price feed addresses
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesLengthsMustBeTheSame.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));

    }


    // PRICE TEST
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 3e32;
        uint256 actualUsd = dsce._getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }
    function testGetTokenAmountFromUsd() public {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, (actualWeth * PRICE_PRECISION)); // we multiply by 1e10 to get the price in wei
    }
    // DEPOSIT COLLATERAL TEST
    function testIfCollateralIsZero() public {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfCollateralIsNotAllowed() public {
        ERC20Mock fakeToken = new ERC20Mock("Fake Token", "FT", User, 100 ether);
        vm.startPrank(User);

        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(fakeToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }
    function testCanDepositColateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 totalCollateralValueInUsd) = dsce.getAccountInformation(User);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce._getUsdValue(weth, AMOUNT_COLLATERAL);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(totalCollateralValueInUsd, expectedDepositAmount);
    }
}
