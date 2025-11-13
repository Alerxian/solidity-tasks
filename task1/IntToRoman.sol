// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

/**
✅  用 solidity 实现整数转罗马数字
题目描述在 https://leetcode.cn/problems/roman-to-integer/description/3.
 */

contract Int2RomanContract {
    function int2Roman(uint num) public pure returns (string memory) {
        require(num > 0 && num < 4000, "Num must be 1~3999");

        bytes[13] memory romans = [
            bytes("M"),
            "CM",
            "D",
            "CD",
            "C",
            "XC",
            "L",
            "XL",
            "X",
            "IX",
            "V",
            "IV",
            "I"
        ];
        uint[13] memory values = [
            uint(1000),
            900,
            500,
            400,
            100,
            90,
            50,
            40,
            10,
            9,
            5,
            4,
            1
        ];

        bytes memory result = new bytes(11);
        uint idx;

        for (uint i = 0; i < values.length; i++) {
            while (num >= values[i]) {
                num -= values[i];
                bytes memory romansChar = romans[i];

                if (romansChar.length == 1) {
                    result[idx++] = romansChar[0];
                } else {
                    result[idx++] = romansChar[0];
                    result[idx++] = romansChar[1];
                }
            }
        }
        return string(result);
    }

    //测试函数：执行所有示例
    function testExamples() public pure returns (string[5] memory results) {
        results[0] = int2Roman(3); // "III"
        results[1] = int2Roman(4); // "IV"
        results[2] = int2Roman(9); // "IX"
        results[3] = int2Roman(58); // "LVIII"
        results[4] = int2Roman(3); // "MCMXCIV"
    }
}
