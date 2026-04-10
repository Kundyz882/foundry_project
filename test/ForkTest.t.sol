// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function test_USDCTotalSupply() public view {
        uint256 supply = IERC20(USDC).totalSupply();
        assertGt(supply, 1_000_000_000e6);
    }

    function test_UniswapSwap() public {
        vm.deal(address(this), 10 ether);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        IUniswapV2Router(ROUTER).swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 balance = IERC20(USDC).balanceOf(address(this));
        assertGt(balance, 0);
    }
}
