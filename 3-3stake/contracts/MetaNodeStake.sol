// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract MetaNodeStake is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    // using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;
    // ************************************** INVARIANT **************************************
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADE_ROLE = keccak256("UPGRADE_ROLE");

    uint256 public constant ETH_PID = 0;

    // ************************************** DATA_STRUCTURE **************************************

    struct Pool {
        // 质押代币地址
        address stTokenAddress;
        // 质押总量
        uint256 stTokenAmount;
        // 每个池子的权重
        uint256 poolWeight;
        // 最后一次计算奖励的区块号
        uint256 lastRewardBlock;
        // 每个质押代币累积的 MetaNode 奖励
        uint256 accMetaNodePerST;
        // 最小质押金额
        uint256 minDepositAmount;
        // 解除质押的锁定区块数
        uint256 unstakeLockedBlocks;
    }

    struct UnStakeRequest {
        // 解除质押的数量
        uint256 amount;
        // 区块从提取奖励所锁定的区块数
        uint256 unlockBlocks;
    }

    struct User {
        // 用户质押的代币数量
        uint256 stAmount;
        // 用户已领取的奖励
        uint256 finishedMetaNode;
        // 用户待领取的奖励
        uint256 pendingMetaNode;
        // 用户的解除质押请求
        UnStakeRequest[] request;
    }

    // ************************************** 状态变量 **************************************
    // 起始区块数
    uint256 public startBlock;
    // 结束区块数
    uint256 public endBlock;
    // 每个区块的 MetaNode 奖励数量
    uint256 public metaNodePerBlock;

    bool public withdrawPaused;
    bool public claimPaused;

    IERC20 public MetaNode;

    Pool[] public pool;
    uint256 public totalPoolWeight;

    mapping(uint256 => mapping(address => User)) public user;

    // ************************************** 修饰符 **************************************
    modifier checkPid(uint256 _pid) {
        require(_pid < pool.length, "invalid pid");
        _;
    }

    modifier whenWithdrawNotPaused() {
        require(!withdrawPaused, "MetaNodeStake: Withdraw is paused");
        _;
    }

    modifier whenClaimNotPaused() {
        require(!claimPaused, "MetaNodeStake: Claim is paused");
        _;
    }

    // ************************************** 事件 **************************************
    event SetMetaNode(address indexed metaNode);
    event SetMetaNOdePerBlock(uint256 indexed metaNodePerBlock);
    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );
    event UpdatePoolInfo(
        uint256 indexed pid,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );
    event SetPoolWeight(
        uint256 indexed pid,
        uint256 poolWeight,
        uint256 totalPoolWeight
    );
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardBlock,
        uint256 totalMetaNode
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event RequestUnStake(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event PausedWithdraw();
    event UnpausedWithdraw();
    event PausedClaim();
    event UnpausedClaim();
    event SetStartBlock(uint256 indexed startBlock);
    event SetEndBlock(uint256 indexed endBlock);
    event Withdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        uint256 blockNumber
    );
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);

    // ************************************** 初始化函数 **************************************
    function initialize(
        address _metaNode,
        uint256 _metaNodePerBlock
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);

        MetaNode = IERC20(_metaNode);
        metaNodePerBlock = _metaNodePerBlock;
        startBlock = block.number;
        endBlock = startBlock + 1_000_000;
        withdrawPaused = false;
        claimPaused = false;
    }

    // 合约升级
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADE_ROLE) {}

    // ************************************** admin function **************************************

    function setMetaNode(address _metaNode) external onlyRole(ADMIN_ROLE) {
        MetaNode = IERC20(_metaNode);

        emit SetMetaNode(_metaNode);
    }

    function setMetaNodePerBlock(
        uint256 _metaNodePerBlock
    ) external onlyRole(ADMIN_ROLE) {
        metaNodePerBlock = _metaNodePerBlock;

        emit SetMetaNOdePerBlock(_metaNodePerBlock);
    }
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function pauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(!withdrawPaused, "MetaNodeStake: Withdraw is already paused");
        withdrawPaused = true;
        emit PausedWithdraw();
    }

    function unpauseWithdraw() public onlyRole(ADMIN_ROLE) {
        require(withdrawPaused, "MetaNodeStake: Withdraw is not paused");
        withdrawPaused = false;
        emit UnpausedWithdraw();
    }

    function pauseClaim() public onlyRole(ADMIN_ROLE) {
        require(!claimPaused, "MetaNodeStake: Claim is already paused");
        claimPaused = true;
        emit PausedClaim();
    }

    function unpauseClaim() public onlyRole(ADMIN_ROLE) {
        require(claimPaused, "MetaNodeStake: Claim is not paused");
        claimPaused = false;
        emit UnpausedClaim();
    }

    function setStartBlock(uint256 _startBlock) external onlyRole(ADMIN_ROLE) {
        require(
            startBlock <= endBlock,
            "MetaNodeStake: startBlock must be less than or equal to endBlock"
        );
        startBlock = _startBlock;

        emit SetStartBlock(_startBlock);
    }

    function setEndBlock(uint256 _endBlock) external onlyRole(ADMIN_ROLE) {
        require(
            _endBlock >= startBlock,
            "MetaNodeStake: endBlock must be greater than or equal to startBlock"
        );
        endBlock = _endBlock;

        emit SetEndBlock(_endBlock);
    }

    // 创建质押池
    function addPool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyRole(ADMIN_ROLE) {
        // 第一个区块一定是ETH池，即address(0)
        if (pool.length > 0) {
            require(
                _stTokenAddress != address(0),
                "MetaNodeStake: ST token address cannot be zero address"
            );
        } else {
            require(
                _stTokenAddress == address(0),
                "MetaNodeStake: The first pool must be the ETH pool"
            );
        }

        require(
            _unstakeLockedBlocks > 0,
            "MetaNodeStake: Unstake locked blocks must be greater than zero"
        );
        require(
            block.number < endBlock,
            "MetaNodeStake: Cannot create pool after end block"
        );

        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalPoolWeight += _poolWeight;

        pool.push(
            Pool({
                stTokenAddress: _stTokenAddress,
                poolWeight: _poolWeight,
                stTokenAmount: 0,
                lastRewardBlock: lastRewardBlock,
                accMetaNodePerST: 0,
                minDepositAmount: _minDepositAmount,
                unstakeLockedBlocks: _unstakeLockedBlocks
            })
        );

        emit AddPool(
            _stTokenAddress,
            _poolWeight,
            lastRewardBlock,
            _minDepositAmount,
            _unstakeLockedBlocks
        );
    }

    // 更新质押池参数
    function updatePool(
        uint256 _pid,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) external onlyRole(ADMIN_ROLE) checkPid(_pid) {
        Pool storage p = pool[_pid];
        p.minDepositAmount = _minDepositAmount;
        p.unstakeLockedBlocks = _unstakeLockedBlocks;

        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    function setPoolWeight(
        uint256 _pid,
        uint256 _poolWeight
    ) external onlyRole(ADMIN_ROLE) checkPid(_pid) {
        require(
            _poolWeight > 0,
            "MetaNodeStake: Pool weight must be greater than zero"
        );

        totalPoolWeight = totalPoolWeight - pool[_pid].poolWeight + _poolWeight;
        pool[_pid].poolWeight = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight, totalPoolWeight);
    }

    // ************************************** query function **************************************

    function poolLength() external view returns (uint256) {
        return pool.length;
    }

    // 计算从form到to区块的奖励
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256 multiplier) {
        require(_from < _to, "MetaNodeStake: _from must be less than _to");
        if (_from < startBlock) {
            _from = startBlock;
        }
        if (_to > endBlock) {
            _to = endBlock;
        }
        require(
            _from <= _to,
            "MetaNodeStake: _from must be less than or equal to _to after adjustment"
        );

        multiplier = (_to - _from) * metaNodePerBlock;
    }

    function pendingMetaNode(
        uint256 _pid,
        address _user
    ) public view checkPid(_pid) returns (uint256) {
        return pendingMetaNodeByBlockNumber(_pid, _user, block.number);
    }

    function pendingMetaNodeByBlockNumber(
        uint256 _pid,
        address _user,
        uint256 _blockNumber
    ) public view checkPid(_pid) returns (uint256) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][_user];
        uint256 accMetaNodePerST = pool_.accMetaNodePerST;
        uint256 stAmount = pool_.stTokenAmount;

        if (_blockNumber > pool_.lastRewardBlock && stAmount != 0) {
            uint256 multiplier = getMultiplier(
                pool_.lastRewardBlock,
                _blockNumber
            );
            uint256 metaNodeReward = (multiplier * pool_.poolWeight) /
                totalPoolWeight;
            accMetaNodePerST += (metaNodeReward * (1 ether)) / stAmount;
        }

        return
            (user_.stAmount * accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode +
            user_.pendingMetaNode;
    }

    function stakingBalance(
        uint256 _pid,
        address _user
    ) external view checkPid(_pid) returns (uint256) {
        return user[_pid][_user].stAmount;
    }

    function withdrawAmount(
        uint256 _pid,
        address _user
    )
        external
        view
        checkPid(_pid)
        returns (uint256 requestAmount, uint256 pendingWithdrawAmount)
    {
        User storage user_ = user[_pid][_user];

        for (uint i = 0; i < user_.request.length; i++) {
            // 如果解锁区块小于等于当前区块，表示可以提取
            if (user_.request[i].unlockBlocks <= block.number) {
                pendingWithdrawAmount += user_.request[i].amount;
            }

            requestAmount += user_.request[i].amount;
        }
    }

    // ************************************** 公共函数 **************************************
    function updatePool(uint256 _pid) public checkPid(_pid) {
        Pool storage pool_ = pool[_pid];

        // 如果当前区块小于等于最后奖励区块，直接返回
        if (block.number <= pool_.lastRewardBlock) {
            return;
        }

        uint256 multiplier = getMultiplier(pool_.lastRewardBlock, block.number);
        uint256 totalMetaNode = (multiplier * pool_.poolWeight) /
            totalPoolWeight;
        uint stSupply = pool_.stTokenAmount;
        if (stSupply > 0) {
            totalMetaNode = (totalMetaNode * (1 ether)) / stSupply;
            pool_.accMetaNodePerST += totalMetaNode;
        }

        pool_.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool_.lastRewardBlock, totalMetaNode);
    }

    // 质押代币
    function _deposit(uint256 _pid, uint256 _amount) internal {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        // 更新质押池
        updatePool(_pid);

        if (user_.stAmount > 0) {
            // 用户已有质押
            uint accST = (user_.stAmount * pool_.accMetaNodePerST) / (1 ether);
            // 待领取奖励
            uint256 pending = accST - user_.finishedMetaNode;
            if (pending > 0) {
                user_.pendingMetaNode += pending;
            }
        }

        if (_amount > 0) {
            // 更新用户的质押数量
            user_.stAmount += _amount;
        }

        // 更新质押池的质押总量
        pool_.stTokenAmount += _amount;

        // 更新用户已领取的奖励
        user_.finishedMetaNode =
            (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // 质押ETH
    function depositETH(
        uint256 _pid
    ) external payable whenNotPaused nonReentrant checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        require(
            pool_.stTokenAddress == address(0),
            "invalid staking token address"
        );
        require(
            msg.value >= pool_.minDepositAmount,
            "MetaNodeStake: Deposit amount must be greater than minDepositAmount"
        );

        _deposit(_pid, msg.value);
    }

    // 质押ERC20代币
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) external whenNotPaused nonReentrant checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        require(
            pool_.stTokenAddress != address(0),
            "invalid staking token address"
        );
        require(
            _amount >= pool_.minDepositAmount,
            "MetaNodeStake: Deposit amount must be greater than minDepositAmount"
        );
        if (_amount > 0) {
            IERC20(pool_.stTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }

        _deposit(_pid, _amount);
    }

    // 解除质押
    function unStake(
        uint256 _pid,
        uint256 _amount
    ) external whenNotPaused nonReentrant whenWithdrawNotPaused checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        require(
            _amount > 0 && user_.stAmount >= _amount,
            "MetaNodeStake: invalid unstake amount"
        );
        // 先更新质押池
        updatePool(_pid);

        // 计算待领取奖励 总奖励 - 已领取的奖励
        uint pendingMetaNode_ = (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode;
        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNode += pendingMetaNode_;
        }

        // 更新用户质押数量
        user_.stAmount -= _amount;
        // 创建解除质押请求
        user_.request.push(
            UnStakeRequest({
                amount: _amount,
                unlockBlocks: block.number + pool_.unstakeLockedBlocks
            })
        );
        // 更新质押池质押总量
        pool_.stTokenAmount -= _amount;
        // 更新用户已领取奖励
        user_.finishedMetaNode =
            (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether);

        emit RequestUnStake(msg.sender, _pid, _amount);
    }

    function withdraw(
        uint256 _pid
    ) external whenNotPaused nonReentrant whenWithdrawNotPaused checkPid(_pid) {
        User storage user_ = user[_pid][msg.sender];
        Pool storage pool_ = pool[_pid];

        uint256 pendingWithdraw_;
        uint256 popNum_;

        for (uint i = 0; i < user_.request.length; i++) {
            if (user_.request[i].unlockBlocks > block.number) {
                break;
            }

            pendingWithdraw_ += user_.request[i].amount;
            popNum_++;
        }

        // request数组前移popNum
        for (uint i = 0; i < user_.request.length - popNum_; i++) {
            user_.request[i] = user_.request[i + popNum_];
        }

        // 删除末尾重复的元素，上一步已经前移了popNum个元素
        for (uint i = 0; i < popNum_; i++) {
            user_.request.pop();
        }

        if (pendingWithdraw_ > 0) {
            if (pool_.stTokenAddress == address(0)) {
                _safeETHTransfer(msg.sender, pendingWithdraw_);
            } else {
                IERC20(pool_.stTokenAddress).safeTransfer(
                    msg.sender,
                    pendingWithdraw_
                );
            }
        }

        emit Withdraw(msg.sender, _pid, pendingWithdraw_, block.number);
    }

    // 领取MetaNode代币奖励
    function claim(
        uint256 _pid
    ) external whenNotPaused nonReentrant whenClaimNotPaused checkPid(_pid) {
        Pool storage pool_ = pool[_pid];
        User storage user_ = user[_pid][msg.sender];

        updatePool(_pid);

        uint256 pendingMetaNode_ = (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether) -
            user_.finishedMetaNode +
            user_.pendingMetaNode;

        if (pendingMetaNode_ > 0) {
            user_.pendingMetaNode = 0;
            _safeMetaNodeTransfer(msg.sender, pendingMetaNode_);
        }

        user_.finishedMetaNode =
            (user_.stAmount * pool_.accMetaNodePerST) /
            (1 ether);

        emit Claim(msg.sender, _pid, pendingMetaNode_);
    }

    function _safeMetaNodeTransfer(address _to, uint256 _amount) internal {
        uint256 metaNodeBal = MetaNode.balanceOf(address(this));

        MetaNode.safeTransfer(
            _to,
            _amount > metaNodeBal ? metaNodeBal : _amount
        );
    }

    /**
     * @notice Safe ETH transfer function
     *
     * @param _to        Address to get transferred ETH
     * @param _amount    Amount of ETH to be transferred
     */
    function _safeETHTransfer(address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_to).call{value: _amount}(
            ""
        );

        require(success, "ETH transfer call failed");
        if (data.length > 0) {
            require(
                abi.decode(data, (bool)),
                "ETH transfer operation did not succeed"
            );
        }
    }
}
