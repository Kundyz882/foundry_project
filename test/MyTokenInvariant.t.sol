// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract Handler is Test {
    MyToken public token;
    address[] public actors;

    constructor(MyToken _token) {
        token = _token;
        actors.push(makeAddr("user1"));
        actors.push(makeAddr("user2"));
        actors.push(makeAddr("user3"));
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];

        amount = bound(amount, 0, token.balanceOf(from));

        vm.prank(from);
        token.transfer(to, amount);
    }

    function burn(uint256 actorSeed, uint256 amount) public {
        address actor = actors[actorSeed % actors.length];

        amount = bound(amount, 0, token.balanceOf(actor));

        vm.prank(actor);
        token.burn(amount);
    }
}

contract MyTokenInvariantTest is Test {
    MyToken token;
    Handler handler;

    function setUp() public {
        token = new MyToken("MyToken", "MTK");
        handler = new Handler(token);

        token.mint(handler.actors(0), 1000 ether);
        token.mint(handler.actors(1), 1000 ether);
        token.mint(handler.actors(2), 1000 ether);

        targetContract(address(handler));
    }

    function invariantTotalSupply() public {
        uint256 sum;

        for (uint256 i = 0; i < 3; i++) {
            sum += token.balanceOf(handler.actors(i));
        }

        assertEq(sum, token.totalSupply());
    }

    function invariantBalanceLimit() public {
        for (uint256 i = 0; i < 3; i++) {
            assertLe(token.balanceOf(handler.actors(i)), token.totalSupply());
        }
    }
}