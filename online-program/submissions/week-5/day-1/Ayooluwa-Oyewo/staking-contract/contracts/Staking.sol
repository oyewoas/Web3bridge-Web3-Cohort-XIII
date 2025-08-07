// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITokenB} from "./TokenB.sol";
import {ITokenA} from "./TokenA.sol";
contract Staking {
    ITokenB public tokenB; // Token B for rewards (mintable & burnable)
    ITokenA public tokenA;  // Token A for staking
    uint256 public lockPeriod;

    struct StakeInfo {
        uint256 amount;
        uint256 unlockTime;
    }

    mapping(address => StakeInfo) public stakes;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event StakingDeployed(address indexed tokenA, address indexed tokenB, uint256 lockPeriod);

    // Errors
    error Staking_InsufficientBalance();
    error Staking_NotEnoughTokens();
    error Staking_LockPeriodNotOver();
    error Staking_ZeroAmount();
    error Staking_AlreadyStaked();
    error Staking_NotStaked();
    error Staking_StakingTokenAddressNotSet();
    error Staking_RewardTokenAddressNotSet();
    error Staking_NoLockPeriodSet();

    constructor(address _tokenA, address _tokenB, uint256 _lockPeriod) {
        if(_tokenA == address(0)) revert Staking_StakingTokenAddressNotSet();
        if(_tokenB == address(0)) revert Staking_RewardTokenAddressNotSet();
        if(_lockPeriod == 0) revert Staking_NoLockPeriodSet();

        tokenA = ITokenA(_tokenA);
        tokenB = ITokenB(_tokenB);
        lockPeriod = _lockPeriod;

        emit StakingDeployed(_tokenA, _tokenB, _lockPeriod);
    }

    function stake(uint256 amount) external {
        if (amount == 0) revert Staking_ZeroAmount();
        if (tokenA.balanceOf(msg.sender) < amount) revert Staking_NotEnoughTokens();
        if (stakes[msg.sender].amount > 0) revert Staking_AlreadyStaked();

        tokenA.transferFrom(msg.sender, address(this), amount);

        stakes[msg.sender].amount += amount;
        stakes[msg.sender].unlockTime = block.timestamp + lockPeriod;

        tokenB.mint(msg.sender, amount); // mint Token B (1:1)

        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        if (amount == 0) revert Staking_ZeroAmount();
        if (stakeInfo.amount == 0) revert Staking_NotStaked();
        if (stakeInfo.amount < amount) revert Staking_InsufficientBalance();
        if (block.timestamp < stakeInfo.unlockTime) revert Staking_LockPeriodNotOver();

        stakeInfo.amount -= amount;

        tokenB.burn(msg.sender, amount); // burn Token B
        tokenA.transfer(msg.sender, amount);

        if (stakeInfo.amount == 0) {
            delete stakes[msg.sender];
        }

        emit Unstaked(msg.sender, amount);
    }

    function getStakeInfo(address user) external view returns (uint256 amount, uint256 unlockTime) {
        StakeInfo memory info = stakes[user];
        return (info.amount, info.unlockTime);
    }
}
