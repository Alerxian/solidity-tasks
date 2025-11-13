// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

/**
✅ 创建一个名为Voting的合约，包含以下功能：
一个mapping来存储候选人的得票数
一个vote函数，允许用户投票给某个候选人
一个getVotes函数，返回某个候选人的得票数
一个resetVotes函数，重置所有候选人的得票数
 */
contract Voting {
    mapping(uint => uint) private votes;
    uint[] ids;
    mapping(uint => bool) private idExists;

    function vote(uint id) external {
        if (!idExists[id]) {
            ids.push(id);
            idExists[id] = true;
        }
        votes[id] += 1;
    }

    function getVotes(uint id) external view returns (uint score) {
        return votes[id];
    }

    function resetVotes() external {
        for (uint i = 0; i < ids.length; i++) {
            delete votes[ids[i]];
            delete idExists[ids[i]];
        }
        delete ids;
    }
}
