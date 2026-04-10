// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./LPToken.sol";

contract AMM {
    IERC20 public tokenA;
    IERC20 public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE = 3;

    event LiquidityAdded(address user, uint256 amountA, uint256 amountB, uint256 lp);
    event LiquidityRemoved(address user, uint256 amountA, uint256 amountB, uint256 lp);
    event Swap(address user, address tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != _tokenB);

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        lpToken = new LPToken();
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external returns (uint256 lp) {
        require(amountA > 0 && amountB > 0);

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        if (lpToken.totalSupply() == 0) {
            lp = sqrt(amountA * amountB);
        } else {
            require(amountA * reserveB == amountB * reserveA);
            lp = min(
                (amountA * lpToken.totalSupply()) / reserveA,
                (amountB * lpToken.totalSupply()) / reserveB
            );
        }

        reserveA += amountA;
        reserveB += amountB;

        lpToken.mint(msg.sender, lp);

        emit LiquidityAdded(msg.sender, amountA, amountB, lp);
    }

    function removeLiquidity(uint256 lp) external returns (uint256 amountA, uint256 amountB) {
        require(lp > 0);

        uint256 total = lpToken.totalSupply();

        amountA = (lp * reserveA) / total;
        amountB = (lp * reserveB) / total;

        lpToken.burn(msg.sender, lp);

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lp);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minOut) external returns (uint256 amountOut) {
        require(amountIn > 0);
        require(tokenIn == address(tokenA) || tokenIn == address(tokenB));
        require(reserveA > 0 && reserveB > 0);

        bool isA = tokenIn == address(tokenA);

        (IERC20 inToken, IERC20 outToken, uint256 reserveIn, uint256 reserveOut) =
            isA ? (tokenA, tokenB, reserveA, reserveB) : (tokenB, tokenA, reserveB, reserveA);

        inToken.transferFrom(msg.sender, address(this), amountIn);

        uint256 amountInWithFee = amountIn * 997;

        amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);

        require(amountOut >= minOut);

        if (isA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        outToken.transfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256)
    {
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}