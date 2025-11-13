// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

/**
✅  用 solidity 二分查找 (Binary Search)
题目描述：在一个有序数组中查找目标值。
 */

contract BinarySort {
    function binarySort(
        uint[] memory nums,
        uint target
    ) public pure returns (uint) {
        uint left = 0;
        uint right = nums.length;

        while (left < right) {
            uint mid = left + (right - left) / 2;
            if (nums[mid] == target) {
                return mid;
            } else if (nums[mid] < target) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return type(uint).max; // 如果未找到，返回最大uint值表示未找到
    }
}
