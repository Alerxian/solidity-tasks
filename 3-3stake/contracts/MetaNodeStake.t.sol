// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MetaNodeStake} from "./MetaNodeStake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "./MockERC20.sol";

contract MetaNodeStakeTest is Test {
  MetaNodeStake stake;
  IERC20 reward;
  IERC20 erc20;

  function setUp() public {
    MockERC20 rewardImpl = new MockERC20("Reward", "RWD", 18);
    MockERC20 erc20Impl = new MockERC20("StakeToken", "STK", 18);
    rewardImpl.mint(address(this), 1_000_000e18);
    erc20Impl.mint(address(this), 1_000_000e18);
    reward = IERC20(address(rewardImpl));
    erc20 = IERC20(address(erc20Impl));
    stake = new MetaNodeStake();
    stake.initialize(address(reward), 1e18);
  }

  function test_InitializeRoles() public {
    bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 UPGRADE_ROLE = keccak256("UPGRADE_ROLE");
    assertTrue(stake.hasRole(ADMIN_ROLE, address(this)));
    assertTrue(stake.hasRole(UPGRADE_ROLE, address(this)));
  }

  function test_SetMetaNodePerBlock() public {
    stake.setMetaNodePerBlock(2e18);
    assertEq(stake.metaNodePerBlock(), 2e18);
  }

  function test_FirstPoolMustBeETH() public {
    vm.expectRevert(bytes("MetaNodeStake: The first pool must be the ETH pool"));
    stake.addPool(address(erc20), 100, 0, 1000);
  }

  function test_CreatePoolsAndWeights() public {
    // First pool: native
    stake.addPool(address(0), 100, 1e15, 1000);
    // Second pool: ERC20
    stake.addPool(address(erc20), 200, 1e15, 2000);

    assertEq(stake.poolLength(), 2);
    // total weight should be 300
    assertEq(stake.totalPoolWeight(), 300);

    // Update weight
    stake.setPoolWeight(1, 500);
    assertEq(stake.totalPoolWeight(), 600);
  }

  function test_GetMultiplierWithinWindow() public {
    uint256 start = stake.startBlock();
    uint256 to = start + 100;
    uint256 mul = stake.getMultiplier(start, to);
    // metaNodePerBlock is 1e18 set in initialize
    assertEq(mul, 100 * 1e18);
  }

  function test_UpdatePoolNoStake() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    vm.roll(block.number + 50);
    stake.updatePool(0);
    (address stTokenAddress,,,,uint256 accMetaNodePerST,,) = stake.pool(0);
    assertEq(stTokenAddress, address(0));
    assertEq(accMetaNodePerST, 0);
  }

  function test_PendingMetaNodeZeroWhenNoStake() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    uint256 pending = stake.pendingMetaNode(0, address(this));
    assertEq(pending, 0);
  }

  function test_RevertCreatePoolAfterEndBlock() public {
    // push chain beyond endBlock
    vm.roll(stake.endBlock() + 1);
    vm.expectRevert(bytes("MetaNodeStake: Cannot create pool after end block"));
    stake.addPool(address(0), 100, 1e15, 1000);
  }

  function test_SetMetaNode() public {
    MockERC20 newReward = new MockERC20("NewReward", "NRD", 18);
    stake.setMetaNode(address(newReward));
    assertEq(address(stake.MetaNode()), address(newReward));
  }

  function test_CreatePool_SetsFields() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    (address stTokenAddress,uint256 stTokenAmount,uint256 weight,uint256 lastRewardBlock,uint256 acc,uint256 min,uint256 locked) = stake.pool(0);
    assertEq(stTokenAddress, address(0));
    assertEq(stTokenAmount, 0);
    assertEq(weight, 100);
    assertEq(min, 1e15);
    assertEq(locked, 1000);
    assertGe(lastRewardBlock, stake.startBlock());
    assertEq(acc, 0);
  }

  function test_UpdatePoolInfo_SetMinAndLocked() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    stake.updatePool(0, 2e15, 2000);
    (, , , , , uint256 min, uint256 locked) = stake.pool(0);
    assertEq(min, 2e15);
    assertEq(locked, 2000);
  }

  function test_CreatePool_SecondZeroAddressRevert() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    vm.expectRevert(bytes("MetaNodeStake: ST token address cannot be zero address"));
    stake.addPool(address(0), 200, 1e15, 2000);
  }

  function test_SetPoolWeight_RevertZero() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    vm.expectRevert(bytes("MetaNodeStake: Pool weight must be greater than zero"));
    stake.setPoolWeight(0, 0);
  }

  function test_PoolLength_AfterCreate() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    stake.addPool(address(erc20), 200, 1e15, 2000);
    assertEq(stake.poolLength(), 2);
  }

  function test_SetStartAndEndBlock() public {
    uint256 s = stake.startBlock();
    stake.setStartBlock(s + 5);
    assertEq(stake.startBlock(), s + 5);
    stake.setEndBlock(s + 1000);
    assertEq(stake.endBlock(), s + 1000);
  }

  function test_GetMultiplier_AdjustStart() public {
    uint256 to = stake.startBlock() + 10;
    uint256 mul = stake.getMultiplier(stake.startBlock() - 5, to);
    assertEq(mul, 10 * 1e18);
  }

  function test_GetMultiplier_AdjustEnd() public {
    uint256 mul = stake.getMultiplier(stake.startBlock(), stake.endBlock() + 100);
    assertEq(mul, (stake.endBlock() - stake.startBlock()) * 1e18);
  }

  function test_GetMultiplier_Revert_FromLessThanTo() public {
    uint256 s = stake.startBlock();
    vm.expectRevert(bytes("MetaNodeStake: _from must be less than _to"));
    stake.getMultiplier(s + 10, s + 10);
  }

  function test_GetMultiplier_Revert_AfterAdjustmentInvalid() public {
    uint256 s = stake.startBlock();
    vm.expectRevert(bytes("MetaNodeStake: _from must be less than or equal to _to after adjustment"));
    stake.getMultiplier(s - 10, s - 5);
  }

  function test_UpdatePool_WithStakeAccrual() public {
    stake.addPool(address(0), 100, 1, 1000);
    stake.depositETH{value: 1 ether}(0);
    vm.roll(block.number + 50);
    stake.updatePool(0);
    (,, , uint256 lastRewardBlock, uint256 acc,,) = stake.pool(0);
    assertEq(lastRewardBlock, block.number);
    assertGt(acc, 0);
  }

  function test_DepositETH_Success() public {
    stake.addPool(address(0), 100, 1e15, 1000);
    stake.depositETH{value: 1 ether}(0);
    (address stTokenAddress,uint256 stTokenAmount,, , , ,) = stake.pool(0);
    assertEq(stTokenAddress, address(0));
    assertEq(stTokenAmount, 1 ether);
    (uint256 stAmount,,) = stake.user(0, address(this));
    assertEq(stAmount, 1 ether);
  }

  function test_DepositETH_Revert_Min() public {
    stake.addPool(address(0), 100, 1 ether, 1000);
    vm.expectRevert(bytes("MetaNodeStake: Deposit amount must be greater than minDepositAmount"));
    stake.depositETH{value: 0.5 ether}(0);
  }

  function test_DepositERC20_Success() public {
    stake.addPool(address(erc20), 200, 1e15, 2000);
    MockERC20(address(erc20)).mint(address(this), 10 ether);
    MockERC20(address(erc20)).approve(address(stake), 5 ether);
    stake.deposit(0 + 1, 5 ether);
    (address stTokenAddress,uint256 stTokenAmount,, , , ,) = stake.pool(1);
    assertEq(stTokenAddress, address(erc20));
    assertEq(stTokenAmount, 5 ether);
    (uint256 stAmount,,) = stake.user(1, address(this));
    assertEq(stAmount, 5 ether);
  }

  function test_DepositERC20_Revert_Min() public {
    stake.addPool(address(erc20), 200, 2 ether, 2000);
    MockERC20(address(erc20)).mint(address(this), 10 ether);
    MockERC20(address(erc20)).approve(address(stake), 1 ether);
    vm.expectRevert(bytes("MetaNodeStake: Deposit amount must be greater than minDepositAmount"));
    stake.deposit(0 + 1, 1 ether);
  }

  function test_UnStake_CreatesRequestAndUpdates() public {
    stake.addPool(address(erc20), 200, 1e15, 2);
    MockERC20(address(erc20)).mint(address(this), 10 ether);
    MockERC20(address(erc20)).approve(address(stake), 5 ether);
    stake.deposit(1, 5 ether);
    vm.roll(block.number + 1);
    stake.unStake(1, 2 ether);
    (uint256 stAmount,,) = stake.user(1, address(this));
    assertEq(stAmount, 3 ether);
    (,uint256 stTokenAmount,, , , ,) = stake.pool(1);
    assertEq(stTokenAmount, 3 ether);
  }

  function test_Withdraw_ETH_Flow() public {
    stake.addPool(address(0), 200, 1, 2);
    stake.depositETH{value: 3 ether}(0);
    stake.unStake(0, 1 ether);
    (uint256 reqAmt, uint256 pendingAmt) = stake.withdrawAmount(0, address(this));
    assertEq(reqAmt, 1 ether);
    assertEq(pendingAmt, 0);
    vm.roll(block.number + 2);
    (reqAmt, pendingAmt) = stake.withdrawAmount(0, address(this));
    assertEq(reqAmt, 1 ether);
    assertEq(pendingAmt, 1 ether);
    uint256 balBefore = address(this).balance;
    stake.withdraw(0);
    uint256 balAfter = address(this).balance;
    assertEq(balAfter - balBefore, 1 ether);
    (reqAmt, pendingAmt) = stake.withdrawAmount(0, address(this));
    assertEq(reqAmt, 0);
    assertEq(pendingAmt, 0);
  }

  function test_Withdraw_ERC20_Flow() public {
    stake.addPool(address(erc20), 200, 1, 2);
    MockERC20(address(erc20)).mint(address(this), 5 ether);
    MockERC20(address(erc20)).approve(address(stake), 5 ether);
    stake.deposit(1, 5 ether);
    stake.unStake(1, 2 ether);
    (uint256 reqAmt, uint256 pendingAmt) = stake.withdrawAmount(1, address(this));
    assertEq(reqAmt, 2 ether);
    assertEq(pendingAmt, 0);
    vm.roll(block.number + 2);
    (reqAmt, pendingAmt) = stake.withdrawAmount(1, address(this));
    assertEq(reqAmt, 2 ether);
    assertEq(pendingAmt, 2 ether);
    uint256 balBefore = MockERC20(address(erc20)).balanceOf(address(this));
    stake.withdraw(1);
    uint256 balAfter = MockERC20(address(erc20)).balanceOf(address(this));
    assertEq(balAfter - balBefore, 2 ether);
    (reqAmt, pendingAmt) = stake.withdrawAmount(1, address(this));
    assertEq(reqAmt, 0);
    assertEq(pendingAmt, 0);
  }

  function test_Withdraw_Paused() public {
    stake.addPool(address(erc20), 200, 1, 2);
    MockERC20(address(erc20)).mint(address(this), 3 ether);
    MockERC20(address(erc20)).approve(address(stake), 3 ether);
    stake.deposit(1, 3 ether);
    stake.unStake(1, 1 ether);
    stake.pauseWithdraw();
    vm.expectRevert(bytes("MetaNodeStake: Withdraw is paused"));
    stake.withdraw(1);
    stake.unpauseWithdraw();
    vm.roll(block.number + 2);
    stake.withdraw(1);
    (uint256 reqAmt, uint256 pendingAmt) = stake.withdrawAmount(1, address(this));
    assertEq(reqAmt, 0);
    assertEq(pendingAmt, 0);
  }

  function test_Claim_Flow() public {
    stake.addPool(address(erc20), 200, 1, 2);
    MockERC20(address(erc20)).mint(address(this), 5 ether);
    MockERC20(address(erc20)).approve(address(stake), 5 ether);
    MockERC20(address(reward)).mint(address(stake), 1_000_000 ether);
    stake.deposit(1, 5 ether);
    vm.roll(block.number + 100);
    uint256 balBefore = MockERC20(address(reward)).balanceOf(address(this));
    stake.claim(1);
    uint256 balAfter = MockERC20(address(reward)).balanceOf(address(this));
    assertGt(balAfter, balBefore);
  }

  function test_Claim_Paused() public {
    stake.addPool(address(erc20), 200, 1, 2);
    MockERC20(address(erc20)).mint(address(this), 2 ether);
    MockERC20(address(erc20)).approve(address(stake), 2 ether);
    MockERC20(address(reward)).mint(address(stake), 1_000_000 ether);
    stake.deposit(1, 2 ether);
    vm.roll(block.number + 10);
    stake.pauseClaim();
    vm.expectRevert(bytes("MetaNodeStake: Claim is paused"));
    stake.claim(1);
    stake.unpauseClaim();
    stake.claim(1);
  }

  function test_StakingBalance_View() public {
    stake.addPool(address(erc20), 200, 1, 2);
    MockERC20(address(erc20)).mint(address(this), 1 ether);
    MockERC20(address(erc20)).approve(address(stake), 1 ether);
    stake.deposit(1, 1 ether);
    uint256 bal = stake.stakingBalance(1, address(this));
    assertEq(bal, 1 ether);
  }

  function test_InvalidPid_Revert() public {
    vm.expectRevert(bytes("invalid pid"));
    stake.depositETH{value: 1 ether}(0);
  }

  function test_PendingMetaNode_WithStake() public {
    stake.addPool(address(0), 100, 1, 1000);
    stake.depositETH{value: 2 ether}(0);
    vm.roll(block.number + 100);
    uint256 pending = stake.pendingMetaNode(0, address(this));
    assertGt(pending, 0);
  }

  function test_PendingMetaNodeByBlockNumber() public {
    stake.addPool(address(0), 100, 1, 1000);
    stake.depositETH{value: 1 ether}(0);
    uint256 target = block.number + 50;
    uint256 pending = stake.pendingMetaNodeByBlockNumber(0, address(this), target);
    assertGt(pending, 0);
  }

  function test_Pause_Unpause_DepositETH() public {
    stake.addPool(address(0), 100, 1, 1000);
    stake.pause();
    vm.expectRevert(bytes("Pausable: paused"));
    stake.depositETH{value: 1 ether}(0);
    stake.unpause();
    stake.depositETH{value: 1 ether}(0);
    (,uint256 stTokenAmount,, , , ,) = stake.pool(0);
    assertEq(stTokenAmount, 1 ether);
  }

  function test_Pause_Unpause_DepositERC20() public {
    stake.addPool(address(erc20), 200, 1, 1000);
    MockERC20(address(erc20)).mint(address(this), 2 ether);
    MockERC20(address(erc20)).approve(address(stake), 2 ether);
    stake.pause();
    vm.expectRevert(bytes("Pausable: paused"));
    stake.deposit(1, 1 ether);
    stake.unpause();
    stake.deposit(1, 1 ether);
    (,uint256 stTokenAmount,, , , ,) = stake.pool(1);
    assertEq(stTokenAmount, 1 ether);
  }

  function test_Pause_Unpause_UnStake() public {
    stake.addPool(address(erc20), 200, 1, 1000);
    MockERC20(address(erc20)).mint(address(this), 3 ether);
    MockERC20(address(erc20)).approve(address(stake), 3 ether);
    stake.deposit(1, 3 ether);
    stake.pause();
    vm.expectRevert(bytes("Pausable: paused"));
    stake.unStake(1, 1 ether);
    stake.unpause();
    stake.unStake(1, 1 ether);
    (uint256 stAmount,,) = stake.user(1, address(this));
    assertEq(stAmount, 2 ether);
  }
}
