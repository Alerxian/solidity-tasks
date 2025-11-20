// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.21;

contract BeggingContract {
    mapping(address => uint256) private _donates;
    address private owner;

    struct Donor {
        address addr;
        uint256 amount;
    }

    Donor[3] private topDonors; // 前3名捐赠者排行榜

    bool private timeRestrictionEnabled;
    uint256 private donationStartTime;
    uint256 private donationEndTime;

    event Donation(address indexed donor, uint256 indexed amount, uint256 timestamp);
    event FundsWithdraw(address indexed owner, uint256 indexed balance, uint256 timestamp);
    event TimeRestrictionSet(uint256 start, uint256 end);
    event TimeRestrictionDisabled();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier withinDonationTime() {
        if (timeRestrictionEnabled) {
            require(block.timestamp >= donationStartTime && block.timestamp <= donationEndTime, "donation not allowed now");
        }
        _;
    }

    function donate() external payable withinDonationTime {
        require(msg.value > 0, "donate value must be large than 0");

        _donates[msg.sender] += msg.value; // 记录捐赠金额
        emit Donation(msg.sender, msg.value, block.timestamp);

        _updateTopDonors(msg.sender);
    }

    function withdraw() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No funds to withdraw");

        payable(owner).transfer(contractBalance);

        emit FundsWithdraw(owner, contractBalance, block.timestamp);
    }

    function getDonation(address addr) external view returns (uint256) {
        return _donates[addr];
    }

    function setDonationTimeRestriction(uint256 start, uint256 end) external onlyOwner {
        require(end > start, "invalid time range");
        donationStartTime = start;
        donationEndTime = end;
        timeRestrictionEnabled = true;
        emit TimeRestrictionSet(start, end);
    }

    function disableTimeRestriction() external onlyOwner {
        timeRestrictionEnabled = false;
        emit TimeRestrictionDisabled();
    }

    function getDonationTimeRestriction() external view returns (bool enabled, uint256 start, uint256 end) {
        return (timeRestrictionEnabled, donationStartTime, donationEndTime);
    }

    function getTopDonors() external view returns (address[3] memory addrs, uint256[3] memory amounts) {
        for (uint256 i = 0; i < 3; i++) {
            addrs[i] = topDonors[i].addr;
            amounts[i] = topDonors[i].amount;
        }
    }

    function _updateTopDonors(address donor) internal {
        uint256 total = _donates[donor];

        // 若已在榜单，更新金额
        for (uint256 i = 0; i < 3; i++) {
            if (topDonors[i].addr == donor) {
                topDonors[i].amount = total;
                _sortTopDonors();
                return;
            }
        }

        // 若存在空位，直接填充
        for (uint256 i = 0; i < 3; i++) {
            if (topDonors[i].addr == address(0)) {
                topDonors[i] = Donor({addr: donor, amount: total});
                _sortTopDonors();
                return;
            }
        }

        // 无空位，若当前总额超过最小者则替换
        uint256 minIndex = 0;
        uint256 minAmount = topDonors[0].amount;
        for (uint256 i = 1; i < 3; i++) {
            if (topDonors[i].amount < minAmount) {
                minAmount = topDonors[i].amount;
                minIndex = i;
            }
        }

        if (total > minAmount) {
            topDonors[minIndex] = Donor({addr: donor, amount: total});
            _sortTopDonors();
        }
    }

    function _sortTopDonors() internal {
        // 简单的三元素降序排序
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = i + 1; j < 3; j++) {
                if (topDonors[j].amount > topDonors[i].amount) {
                    Donor memory tmp = topDonors[i];
                    topDonors[i] = topDonors[j];
                    topDonors[j] = tmp;
                }
            }
        }
    }
}
