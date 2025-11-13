// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

/**
✅ 反转字符串 (Reverse String)
题目描述：反转一个字符串。输入 "abcde"，输出 "edcba"
 */

contract RevertString {
    function reverse(string memory str) external pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint len = strBytes.length;

        for (uint i = 0; i < len / 2; i++) {
            bytes1 temp = strBytes[i];
            strBytes[i] = strBytes[len - 1 - i];
            strBytes[len - 1 - i] = temp;
        }

        return string(strBytes);
    }
}
