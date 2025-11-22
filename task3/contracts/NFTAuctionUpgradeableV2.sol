// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "./NFTAuctionUpgradeable.sol";

contract NFTAuctionUpgradeableV2 is NFTAuctionUpgradeable {
    function sayHello() external pure returns (string memory) {
        return "hello world";
    }
}