// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RewardNFT} from "./RewardNFT.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract NFTStaking {
    using Strings for uint256;

    IERC20 public stakingToken; // ERC20 token to stake
    RewardNFT public rewardNFT; // NFT reward contract
    uint256 public lockPeriod;

    struct StakeInfo {
        uint256 amount;
        uint256 unlockTime;
        uint256 tokenId;
    }

    mapping(address => StakeInfo) public stakes;

    // Events
    event Staked(address indexed user, uint256 amount, uint256 tokenId);
    event Unstaked(address indexed user, uint256 amount, uint256 tokenId);
    event NFTStakingDeployed(address stakingToken, address rewardNFT, uint256 lockPeriod);

    // Errors
    error NFTStaking_AlreadyStaked();
    error NFTStaking_NotStaked();
    error NFTStaking_LockPeriodNotOver();
    error NFTStaking_InvalidAmount();
    error NFTStaking_NotEnoughTokens();
    error NFTStaking_InvalidToken();
    error NFTStaking_InvalidNFT();
    error NFTStaking_InvalidLockPeriod();

    constructor(address _stakingToken, address _rewardNFT, uint256 _lockPeriod) {
        if (_stakingToken == address(0)) revert NFTStaking_InvalidToken();
        if (_rewardNFT == address(0)) revert NFTStaking_InvalidNFT();
        if (_lockPeriod <= 0) revert NFTStaking_InvalidLockPeriod();

        stakingToken = IERC20(_stakingToken);
        rewardNFT = RewardNFT(_rewardNFT);
        lockPeriod = _lockPeriod;

        emit NFTStakingDeployed(_stakingToken, _rewardNFT, _lockPeriod);
    }

    function stake(uint256 amount) external {
        if (amount <= 0) revert NFTStaking_InvalidAmount();
        if (stakingToken.balanceOf(msg.sender) < amount) revert NFTStaking_NotEnoughTokens();
        if (stakes[msg.sender].amount > 0) revert NFTStaking_AlreadyStaked();

        stakingToken.transferFrom(msg.sender, address(this), amount);

        uint256 unlockTime = block.timestamp + lockPeriod;

        string[] memory attributes = new string[](2);
        string[] memory values = new string[](2);
        attributes[0] = "Stake Amount";
        attributes[1] = "Unlock Time";
        values[0] = Strings.toString(amount);
        values[1] = Strings.toString(unlockTime);

        string memory color = "green";

        uint256 tokenId = rewardNFT.mintWithGeneratedImage(
            msg.sender,
            "Staking Reward NFT",
            "This NFT represents your staking position and reward.",
            color,
            attributes,
            values
        );

        stakes[msg.sender] = StakeInfo({
            amount: amount,
            unlockTime: unlockTime,
            tokenId: tokenId
        });

        emit Staked(msg.sender, amount, tokenId);
    }

    function unstake() external {
        StakeInfo memory info = stakes[msg.sender];
        if (info.amount <= 0) revert NFTStaking_NotStaked();
        if (block.timestamp < info.unlockTime) revert NFTStaking_LockPeriodNotOver();

        stakingToken.transfer(msg.sender, info.amount);
        rewardNFT.burn(info.tokenId);

        delete stakes[msg.sender];

        emit Unstaked(msg.sender, info.amount, info.tokenId);
    }

    function getStakeInfo(address user) external view returns (uint256 amount, uint256 unlockTime, uint256 tokenId) {
        StakeInfo memory info = stakes[user];
        return (info.amount, info.unlockTime, info.tokenId);
    }
}
