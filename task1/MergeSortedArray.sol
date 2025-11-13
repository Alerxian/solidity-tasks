// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

/**
✅  用 solidity 合并两个有序数组
 */

contract MergeSortedArray {
    function merge(
        uint[] memory nums1,
        uint[] memory nums2
    ) public pure returns (uint[] memory) {
        uint m = nums1.length;
        uint n = nums2.length;
        uint[] memory mergedArray = new uint[](m + n);
        uint i;
        uint j;
        uint k;

        while (i < m && j < n) {
            if (nums1[i] < nums2[j]) {
                mergedArray[k++] = nums1[i++];
            } else {
                mergedArray[k++] = nums2[j++];
            }
        }
        while (i < m) mergedArray[k++] = nums1[i++];
        while (j < n) mergedArray[k++] = nums2[j++];

        return mergedArray;
    }
}
