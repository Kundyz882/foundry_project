// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract LPToken is ERC20 {
    address public amm;

    constructor() ERC20("LP Token", "LPT") {
        amm = msg.sender;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == amm);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(msg.sender == amm);
        _burn(from, amount);
    }
}