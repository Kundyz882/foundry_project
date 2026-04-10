// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        token = new MyToken("MyToken", "MTK");
        token.mint(alice, 1000 ether);
    }

    function testMintBalance() public {
        assertEq(token.balanceOf(alice), 1000 ether);
    }

    function testMintSupply() public {
        assertEq(token.totalSupply(), 1000 ether);
    }

    function testMintRevertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(bob, 1);
    }

    function testMintZeroAddress() public {
        vm.expectRevert();
        token.mint(address(0), 1);
    }

    function testTransfer() public {
        vm.prank(alice);
        token.transfer(bob, 100 ether);
        assertEq(token.balanceOf(bob), 100 ether);
    }

    function testTransferFail() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(bob, 2000 ether);
    }

    function testTransferZero() public {
        vm.prank(alice);
        vm.expectRevert();
        token.transfer(address(0), 1);
    }

    function testApprove() public {
        vm.prank(alice);
        token.approve(bob, 100 ether);
        assertEq(token.allowance(alice, bob), 100 ether);
    }

    function testTransferFrom() public {
        vm.prank(alice);
        token.approve(bob, 200 ether);

        vm.prank(bob);
        token.transferFrom(alice, bob, 100 ether);

        assertEq(token.balanceOf(bob), 100 ether);
    }

    function testTransferFromFail() public {
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, bob, 1);
    }

    function testBurn() public {
        vm.prank(alice);
        token.burn(500 ether);
        assertEq(token.totalSupply(), 500 ether);
    }

    function testFuzzTransfer(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);

        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount);
    }
}