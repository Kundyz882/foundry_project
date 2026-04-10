// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract LendingPool {
    IERC20 public collateralToken;
    address public owner;

    uint256 public constant LTV = 75;
    uint256 public interestRate = 5;
    uint256 public collateralPrice = 1e18;

    struct Position {
        uint256 collateral;
        uint256 debt;
        uint256 lastUpdated;
    }

    mapping(address => Position) public positions;

    event Deposited(address user, uint256 amount);
    event Borrowed(address user, uint256 amount);
    event Repaid(address user, uint256 amount);
    event Withdrawn(address user, uint256 amount);
    event Liquidated(address user, address liquidator);
    event CollateralPriceUpdated(uint256 newPrice);

    constructor(address _collateralToken) {
        owner = msg.sender;
        collateralToken = IERC20(_collateralToken);
    }

    function _accrueInterest(address user) internal {
        Position storage p = positions[user];

        if (p.debt == 0) {
            p.lastUpdated = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - p.lastUpdated;

        uint256 interest = (p.debt * interestRate * timeElapsed) / (365 days * 100);

        p.debt += interest;
        p.lastUpdated = block.timestamp;
    }

    function deposit(uint256 amount) external {
        require(amount > 0);

        _accrueInterest(msg.sender);

        collateralToken.transferFrom(msg.sender, address(this), amount);

        positions[msg.sender].collateral += amount;

        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0);

        _accrueInterest(msg.sender);

        Position storage p = positions[msg.sender];

        uint256 maxBorrow = (_collateralValue(p.collateral) * LTV) / 100;

        require(p.debt + amount <= maxBorrow, "LTV exceeded");

        p.debt += amount;
        p.lastUpdated = block.timestamp;

        collateralToken.transfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0);

        _accrueInterest(msg.sender);

        Position storage p = positions[msg.sender];

        collateralToken.transferFrom(msg.sender, address(this), amount);

        if (amount >= p.debt) {
            p.debt = 0;
        } else {
            p.debt -= amount;
        }

        emit Repaid(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0);

        _accrueInterest(msg.sender);

        Position storage p = positions[msg.sender];

        require(p.collateral >= amount);

        uint256 newCollateral = p.collateral - amount;

        require(_healthFactor(newCollateral, p.debt) > 1e18, "HF low");

        p.collateral = newCollateral;

        collateralToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external {
        _accrueInterest(user);

        Position storage p = positions[user];

        require(_healthFactor(p.collateral, p.debt) < 1e18, "Healthy");
        uint256 debt = p.debt;
        uint256 collateral = p.collateral;

        p.debt = 0;
        p.collateral = 0;

        collateralToken.transferFrom(msg.sender, address(this), debt);
        collateralToken.transfer(msg.sender, collateral);

        emit Liquidated(user, msg.sender);
    }

    function setCollateralPrice(uint256 newPrice) external {
        require(msg.sender == owner, "Not owner");
        require(newPrice > 0, "Invalid price");
        collateralPrice = newPrice;

        emit CollateralPriceUpdated(newPrice);
    }

    function healthFactor(address user) external view returns (uint256) {
        Position memory p = positions[user];
        uint256 debtWithInterest = _debtWithInterest(p);
        return _healthFactor(p.collateral, debtWithInterest);
    }

    function _debtWithInterest(Position memory p) internal view returns (uint256) {
        if (p.debt == 0) return 0;

        uint256 timeElapsed = block.timestamp - p.lastUpdated;
        uint256 interest = (p.debt * interestRate * timeElapsed) / (365 days * 100);
        return p.debt + interest;
    }

    function _collateralValue(uint256 collateral) internal view returns (uint256) {
        return (collateral * collateralPrice) / 1e18;
    }

    function _healthFactor(uint256 collateral, uint256 debt)
        internal
        view
        returns (uint256)
    {
        if (debt == 0) return type(uint256).max;
        return (_collateralValue(collateral) * 1e18) / debt;
    }
}
