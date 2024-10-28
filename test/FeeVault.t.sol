// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {Constants} from "./Constants.sol";
import {IERC20} from "@openzeppelin-contracts/token/ERC20/IERC20.sol";

contract FeeVaultTest is Test, Constants {
    FeeVault feeVault;

    function setUp() public {
        FeeVault.FeeInfo[] memory infos = new FeeVault.FeeInfo[](3);
        infos[0] = FeeVault.FeeInfo(ADMIN, TREASURY, 6000);
        infos[1] = FeeVault.FeeInfo(ALICE, ALICE, 2000);
        infos[2] = FeeVault.FeeInfo(BOB, BOB, 2000);
        feeVault = new FeeVault(WMNT, infos);
        // deal WBTC to feeVault
        deal(WBTC, address(feeVault), 1e8);
        // deal USDC to feeVault
        deal(USDC, address(feeVault), 1000 * 1e6);
        // deal WETH to feeVault
        deal(WETH, address(feeVault), 1000 * 1e18);
        // send native token to feeVault
        deal(ALICE, 1e18);
        vm.startPrank(ALICE, ALICE);
        (bool flag,) = address(feeVault).call{value: 1e18}("");
        require(flag, "FeeVaultTest: send native token failed");
        vm.stopPrank();
    }

    function deployInvaildAdmin() public {
        FeeVault.FeeInfo[] memory infos = new FeeVault.FeeInfo[](1);
        infos[0] = FeeVault.FeeInfo(address(0), TREASURY, 10_000);
        vm.expectRevert("FeeVault: invalid admin");
        feeVault = new FeeVault(WMNT, infos);
    }

    function deployInvaildTreasury() public {
        FeeVault.FeeInfo[] memory infos = new FeeVault.FeeInfo[](2);
        infos[0] = FeeVault.FeeInfo(ADMIN, TREASURY, 6000);
        infos[1] = FeeVault.FeeInfo(ALICE, address(0), 4000);
        vm.expectRevert("FeeVault: invalid treasury");
        feeVault = new FeeVault(WMNT, infos);
    }

    function deployInvaildFee() public {
        FeeVault.FeeInfo[] memory infos = new FeeVault.FeeInfo[](2);
        infos[0] = FeeVault.FeeInfo(ADMIN, TREASURY, 6000);
        infos[1] = FeeVault.FeeInfo(ALICE, ALICE, 3000);
        vm.expectRevert("FeeVault: invalid fee");
        feeVault = new FeeVault(WMNT, infos);
    }

    function testClaim() public {
        address[] memory tokens = new address[](4);
        tokens[0] = WBTC;
        tokens[1] = USDC;
        tokens[2] = WETH;
        tokens[3] = WMNT;
        uint256[] memory balanceTreasuryBfs = new uint256[](4);
        uint256[] memory balanceAliceBfs = new uint256[](4);
        uint256[] memory balanceBobBfs = new uint256[](4);
        uint256[] memory balanceFeeVaultBfs = new uint256[](4);
        for (uint256 i; i < tokens.length; ++i) {
            balanceTreasuryBfs[i] = IERC20(tokens[i]).balanceOf(TREASURY);
            balanceAliceBfs[i] = IERC20(tokens[i]).balanceOf(ALICE);
            balanceBobBfs[i] = IERC20(tokens[i]).balanceOf(BOB);
            balanceFeeVaultBfs[i] = IERC20(tokens[i]).balanceOf(address(feeVault));
        }
        feeVault.claim(tokens);
        // check that fees was distributed correctly
        for (uint256 i; i < tokens.length; ++i) {
            uint256 balanceTreasuryAfs = IERC20(tokens[i]).balanceOf(TREASURY);
            uint256 balanceAliceAfs = IERC20(tokens[i]).balanceOf(ALICE);
            uint256 balanceBobAfs = IERC20(tokens[i]).balanceOf(BOB);
            uint256 balanceFeeVaultBf = balanceFeeVaultBfs[i];
            require(balanceFeeVaultBf > 0, "FeeVaultTest: balanceFeeVaultBf should not be zero");
            FeeVault.FeeInfo[] memory infos = feeVault.getFeeInfos();
            assertEq(balanceTreasuryAfs - balanceTreasuryBfs[i], infos[0].feeBps * balanceFeeVaultBf / 10_000);
            assertEq(balanceAliceAfs - balanceAliceBfs[i], infos[1].feeBps * balanceFeeVaultBf / 10_000);
            assertEq(balanceBobAfs - balanceBobBfs[i], infos[2].feeBps * balanceFeeVaultBf / 10_000);
        }
    }

    function testClaimRevert() public {
        address[] memory tokens = new address[](1);
        tokens[0] = USDT;
        vm.expectRevert("FeeVault: no balance");
        feeVault.claim(tokens);
    }

    function testSetAdminRevertNotAdmin() public {
        vm.expectRevert("FeeVault: not admin");
        feeVault.setAdmin(1, BEEF);
    }

    function testSetAdminRevertZeroAddress() public {
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert("FeeVault: invalid admin");
        feeVault.setAdmin(1, address(0));
        vm.stopPrank();
    }

    function testSetAdmin() public {
        vm.startPrank(ALICE, ALICE);
        feeVault.setAdmin(1, BOB);
        vm.stopPrank();
        FeeVault.FeeInfo[] memory infos = feeVault.getFeeInfos();
        assertEq(infos[1].admin, BOB);
    }

    function testSetTreasuryRevertNotAdmin() public {
        vm.expectRevert("FeeVault: not admin");
        feeVault.setTreasury(1, BEEF);
    }

    function testSetTreasuryRevertZeroAddress() public {
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert("FeeVault: invalid treasury");
        feeVault.setTreasury(1, address(0));
        vm.stopPrank();
    }

    function testSetTreasury() public {
        vm.startPrank(ALICE, ALICE);
        feeVault.setTreasury(1, BOB);
        vm.stopPrank();
        FeeVault.FeeInfo[] memory infos = feeVault.getFeeInfos();
        assertEq(infos[1].treasury, BOB);
    }
}
