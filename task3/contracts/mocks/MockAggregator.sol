// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

contract MockAggregator is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _price;

    constructor(uint8 decimals_, int256 initialPrice_) {
        _decimals = decimals_;
        _price = initialPrice_;
    }

    function setPrice(int256 price_) external {
        _price = price_;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, _price, block.timestamp, block.timestamp, 0);
    }
}