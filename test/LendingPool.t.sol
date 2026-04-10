// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";
import "../src/TokenA.sol";

contract LendingTest is Test {
    LendingPool pool;
    TokenA token;

    address user = address(1);
    address liquidator = address(2);

    function setUp() public {
        token = new TokenA();
        pool = new LendingPool(address(token));

        token.transfer(user, 1000 ether);
        token.transfer(liquidator, 1000 ether);

        vm.startPrank(user);
        token.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(liquidator);
        token.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.prank(user);
        pool.deposit(100 ether);

        (uint256 collateral,,) = pool.positions(user);
        assertEq(collateral, 100 ether);
    }

    function testBorrowWithinLTV() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        (, uint256 debt,) = pool.positions(user);
        assertEq(debt, 50 ether);
    }

    function testBorrowExceedLTVRevert() public {
        vm.startPrank(user);
        pool.deposit(100 ether);

        vm.expectRevert();
        pool.borrow(100 ether);
        vm.stopPrank();
    }

    function testBorrowWithZeroCollateralRevert() public {
        vm.prank(user);
        vm.expectRevert("LTV exceeded");
        pool.borrow(1 ether);
    }

    function testRepayPartial() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(20 ether);
        vm.stopPrank();

        (, uint256 debt,) = pool.positions(user);
        assertLt(debt, 50 ether);
    }

    function testRepayFull() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(50 ether);
        vm.stopPrank();

        (, uint256 debt,) = pool.positions(user);
        assertEq(debt, 0);
    }

    function testWithdraw() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.withdraw(50 ether);
        vm.stopPrank();

        (uint256 collateral,,) = pool.positions(user);
        assertEq(collateral, 50 ether);
    }

    function testWithdrawFailLowHF() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(70 ether);

        vm.expectRevert();
        pool.withdraw(50 ether);
        vm.stopPrank();
    }

    function testLiquidation() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(70 ether);
        vm.stopPrank();

        pool.setCollateralPrice(6e17);

        vm.startPrank(liquidator);
        pool.liquidate(user);
        vm.stopPrank();

        (uint256 collateral, uint256 debt,) = pool.positions(user);
        assertEq(debt, 0);
        assertEq(collateral, 0);
    }

    function testZeroDepositRevert() public {
        vm.prank(user);
        vm.expectRevert();
        pool.deposit(0);
    }

    function testInterestAccrual() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        vm.prank(user);
        pool.borrow(1 ether);

        (, uint256 debt,) = pool.positions(user);
        assertGt(debt, 50 ether);
    }

    function testHealthFactorView() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        assertEq(pool.healthFactor(user), 2e18);
    }
}
