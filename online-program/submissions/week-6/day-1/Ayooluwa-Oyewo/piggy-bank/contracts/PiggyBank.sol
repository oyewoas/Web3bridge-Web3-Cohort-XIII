/**
Piggy Bank Factory
Objective
Build a piggy bank that allow users to Join and create multiple savings account
Allow them to save either ERC20 or Ethers: they should be able to choose.
Make it a Factory
We must be able to get the balance of each user and make the deployer of the factory the admin.
Track how many savings account the account have.
Track the lock period for each savings plan that a user has on their child contract and they must have different lock periods.
And if they intend to withdraw before the lock period that should incur a 3% breaking fee that would be transferred to the account of the deployer of the factory.
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/Events.sol";
import "./libraries/Errors.sol";
import "./interfaces/IPiggyBank.sol";

contract PiggyBank is IPiggyBank, ReentrancyGuard {
    using SafeERC20 for IERC20;
    enum SavingStatus {
        Inactive,
        Active
    }
    struct SavingsPlan {
        address owner;
        uint256 targetAmount;
        address tokenAddress;
        uint256 balance;
        uint256 lockPeriod;
        uint256 createdAt;
        SavingStatus status;
    }
    SavingsPlan public savingsPlan;
    address public factoryAdmin;
    address public factory;
    uint256 public constant BREAKING_FEE_PERCENTAGE = 3;

    constructor(
        address _owner,
        uint256 _targetAmount,
        address _tokenAddress,
        uint256 _lockPeriod,
        address _factoryAdmin,
        address _factory
    ) {
        savingsPlan = SavingsPlan({
            owner: _owner,
            targetAmount: _targetAmount,
            tokenAddress: _tokenAddress,
            lockPeriod: _lockPeriod,
            balance: 0,
            createdAt: block.timestamp,
            status: SavingStatus.Active
        });
        factoryAdmin = _factoryAdmin;
        factory = _factory;
    }

    modifier onlyOwner() {
        if (msg.sender != savingsPlan.owner) {
            revert Errors.PiggyBank__UnauthorizedAccess();
        }
        _;
    }

    function depositERC20(uint256 amount) external onlyOwner nonReentrant {
        if (savingsPlan.tokenAddress == address(0)) {
            revert Errors.PiggyBank__CanOnlyReceiveETH();
        }
        if (
            amount == 0 ||
            IERC20(savingsPlan.tokenAddress).balanceOf(msg.sender) < amount
        ) {
            revert Errors.PiggyBank__InsufficientFunds();
        }
        if (savingsPlan.status == SavingStatus.Inactive) {
            revert Errors.PiggyBank__SavingsPlanInactive();
        }

        savingsPlan.balance += amount;
        IERC20(savingsPlan.tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        emit Events.SavingsPlanFunded(msg.sender, amount);

        if (savingsPlan.balance >= savingsPlan.targetAmount) {
            emit Events.SavingsTargetReached(msg.sender, savingsPlan.balance);
        }
    }

    function depositETH() external payable onlyOwner nonReentrant {
        if (msg.value == 0) {
            revert Errors.PiggyBank__ZeroValue();
        }
        if (savingsPlan.tokenAddress != address(0)) {
            revert Errors.PiggyBank__CanOnlyReceiveERC20();
        }

        if (savingsPlan.status == SavingStatus.Inactive) {
            revert Errors.PiggyBank__SavingsPlanInactive();
        }
        savingsPlan.balance += msg.value;
        emit Events.SavingsPlanFunded(msg.sender, msg.value);

        if (savingsPlan.balance >= savingsPlan.targetAmount) {
            emit Events.SavingsTargetReached(msg.sender, savingsPlan.balance);
        }
    }

    function withdraw(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) {
            revert Errors.PiggyBank__ZeroValue();
        }
        if (amount > savingsPlan.balance) {
            revert Errors.PiggyBank__InsufficientFunds();
        }

        _transfer(amount);
        if (amount == savingsPlan.balance) {
            savingsPlan.status = SavingStatus.Inactive;
        }

        emit Events.SavingsPlanWithdrawn(msg.sender, amount);
    }

    function setSavingsPlanInactive() external onlyOwner {
        savingsPlan.status = SavingStatus.Inactive;
    }

    function withdrawAll() external onlyOwner nonReentrant {
        uint256 amount = savingsPlan.balance;
        if (amount == 0) {
            revert Errors.PiggyBank__InsufficientFunds();
        }

        _transfer(amount);

        savingsPlan.status = SavingStatus.Inactive;

        emit Events.SavingsPlanWithdrawn(msg.sender, amount);
    }

    // Internal function to handle transfers
    function _transfer(uint256 amount) private {
        uint256 fee;
        if (block.timestamp < savingsPlan.createdAt + savingsPlan.lockPeriod) {
            fee = (amount * BREAKING_FEE_PERCENTAGE) / 100;
        }

        savingsPlan.balance -= amount;

        if (fee > 0) {
            _transferFee(fee);
            amount -= fee;
        }

        _transferToUser(amount);
    }
    function _transferFee(uint256 fee) private {
        if (savingsPlan.tokenAddress == address(0)) {
            (bool success, ) = payable(factoryAdmin).call{value: fee}("");
            if (!success) {
                revert Errors.PiggyBank__FeeTransferFailed();
            }
        } else {
            IERC20(savingsPlan.tokenAddress).safeTransfer(factoryAdmin, fee);
        }
    }

    function _transferToUser(uint256 amount) private {
        if (savingsPlan.tokenAddress == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            if (!success) {
                revert Errors.PiggyBank__TransferFailed();
            }
        } else {
            IERC20(savingsPlan.tokenAddress).safeTransfer(msg.sender, amount);
        }
    }

    // Admin functions
}
