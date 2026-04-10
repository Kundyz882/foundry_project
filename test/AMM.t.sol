// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";

contract AMMTest is Test {
    AMM amm;
    TokenA tokenA;
    TokenB tokenB;

    address user = address(1);

    function setUp() public {
        tokenA = new TokenA();
        tokenB = new TokenB();

        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.transfer(user, 2000 ether);
        tokenB.transfer(user, 2000 ether);

        vm.startPrank(user);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function test_firstLiquidity() public {
        vm.prank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        assertGt(amm.lpToken().balanceOf(user), 0);
    }

    function test_secondLiquidity() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        amm.addLiquidity(500 ether, 500 ether);
        assertGt(amm.lpToken().balanceOf(user), 0);
        vm.stopPrank();
    }

    function test_removeLiquidityFull() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        uint256 lp = amm.lpToken().balanceOf(user);
        amm.removeLiquidity(lp);
        assertEq(amm.lpToken().balanceOf(user), 0);
        vm.stopPrank();
    }

    function test_removeLiquidityPartial() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        uint256 lp = amm.lpToken().balanceOf(user);
        amm.removeLiquidity(lp / 2);
        assertGt(amm.lpToken().balanceOf(user), 0);
        vm.stopPrank();
    }

    function test_swapAtoB() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        uint256 out = amm.swap(address(tokenA), 10 ether, 1);
        assertGt(out, 0);
        vm.stopPrank();
    }

    function test_swapBtoA() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        uint256 out = amm.swap(address(tokenB), 10 ether, 1);
        assertGt(out, 0);
        vm.stopPrank();
    }

    function test_slippageRevert() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        vm.expectRevert();
        amm.swap(address(tokenA), 10 ether, type(uint256).max);
        vm.stopPrank();
    }

    function test_zeroAmountRevert() public {
        vm.prank(user);
        vm.expectRevert();
        amm.swap(address(tokenA), 0, 1);
    }

    function test_kIncreases() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        uint256 k1 = amm.reserveA() * amm.reserveB();
        amm.swap(address(tokenA), 10 ether, 1);
        uint256 k2 = amm.reserveA() * amm.reserveB();
        assertGe(k2, k1);
        vm.stopPrank();
    }

    function test_largeSwap() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        uint256 out = amm.swap(address(tokenA), 500 ether, 1);
        assertGt(out, 0);
        vm.stopPrank();
    }

    function test_singleSidedLiquidityRevert() public {
        vm.prank(user);
        vm.expectRevert();
        amm.addLiquidity(1000 ether, 0);
    }

    function test_invalidTokenRevert() public {
        vm.prank(user);
        vm.expectRevert();
        amm.swap(address(123), 10 ether, 1);
    }

    function test_swapWithoutLiquidityRevert() public {
        vm.prank(user);
        vm.expectRevert();
        amm.swap(address(tokenA), 10 ether, 1);
    }

    function test_getAmountOutMatchesSwap() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);

        uint256 expected = amm.getAmountOut(10 ether, 1000 ether, 1000 ether);
        uint256 actual = amm.swap(address(tokenA), 10 ether, 1);

        assertEq(expected, actual);
        vm.stopPrank();
    }

    function test_reservesUpdate() public {
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        amm.swap(address(tokenA), 10 ether, 1);

        assertGt(amm.reserveA(), 1000 ether);
        assertLt(amm.reserveB(), 1000 ether);
        vm.stopPrank();
    }

    function testFuzz_swap(uint256 amount) public {
        vm.assume(amount > 1 ether && amount < 100 ether);
        vm.startPrank(user);
        amm.addLiquidity(1000 ether, 1000 ether);
        amm.swap(address(tokenA), amount, 1);
        vm.stopPrank();
    }
}
