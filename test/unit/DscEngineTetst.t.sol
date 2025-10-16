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

    function setUp() public {
        deployer = new DeployDsc();
        (dsc, dsce, helperConfig) = deployer.run();
        // we might as well just have for weth, and ethPriceFeed to reduce lines of code
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();

        ERC20Mock(weth).mint(User, STARTING_COLLATERAL);
    }

    // PRICE TEST
    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 3e32;
        uint256 actualUsd = dsce._getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    // DEPOSIT COLLATERAL TEST
    function testIfCollateralIsZero() public {
        vm.startPrank(User);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }
}
