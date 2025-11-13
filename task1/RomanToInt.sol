// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

/**
✅  用 solidity 实现罗马数字转整数
题目描述在 https://leetcode.cn/problems/roman-to-integer/description/3.
 */

contract Roman2IntContract {
    mapping(bytes1 => uint256) private romanMap;

    // 构造函数中初始化映射（合约部署时执行一次）
    constructor() {
        romanMap["I"] = 1;
        romanMap["V"] = 5;
        romanMap["X"] = 10;
        romanMap["L"] = 50;
        romanMap["C"] = 100;
        romanMap["D"] = 500;
        romanMap["M"] = 1000;
    }

    function roman2Int(string memory s) public view returns (uint) {
        bytes memory strBytes = bytes(s);
        uint len = strBytes.length;
        uint res = 0;

        for (uint i = 0; i < len; i++) {
            uint curr = romanMap[strBytes[i]];
            uint next = i + 1 < len ? romanMap[strBytes[i + 1]] : 0; // 超出边界处理

            if (curr < next) {
                // IV
                res += next - curr;
                i++; // 跳过下一个字符
            } else {
                res += curr;
            }
        }

        return res;
    }

    function test() external view returns (uint[5] memory results) {
        results[0] = roman2Int("III"); // 3
        results[1] = roman2Int("IV"); // 4
        results[2] = roman2Int("IX"); // 9
        results[3] = roman2Int("LVIII"); // 58
        results[4] = roman2Int("MCMXCIV"); // 1994
    }
}
