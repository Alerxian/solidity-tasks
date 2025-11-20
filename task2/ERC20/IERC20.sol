// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.21;

interface IERC20 {
    // 转账
    event Transfer(address indexed from, address indexed to, uint256 value);

    // 授权
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // 获取余额
    function balanceOf(address account) external view returns(uint256);

    // 获取总代币数
    function totalSupply() external view returns(uint256);

    // 转账
    function transfer(address to, uint256 amount) external returns(bool); 

    // 返回授权额度
    function allowance(address owner, address spender) external view returns(uint256);

    // 授权
    function approve(address spender, uint256 amount) external returns(bool);

    // 授权转账
    function transferFrom(address from, address to, uint256 amount) external returns(bool);
}