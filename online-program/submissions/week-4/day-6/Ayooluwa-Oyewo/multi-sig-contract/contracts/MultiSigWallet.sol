// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMultiSigWallet {
    function submitTransaction(address destination, uint256 value, bytes calldata data) external returns (uint256 transactionIndex);
    function confirmTransaction(uint256 transactionIndex) external;
    function revokeConfirmation(uint256 transactionIndex) external;
    function executeTransaction(uint256 transactionIndex) external;
    function getTransactionCount() external view returns (uint256);
    function getTransaction(uint256 transactionIndex) external view returns (address destination, uint256 value, bytes memory data, bool executed);
}

contract MultiSigWallet {
    // State variables

    address[] public owners;
    uint256 public requiredConfirmations;
    uint256 public transactionCount;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }

    mapping(uint256 transactionIndex => Transaction transaction) public transactions;
    mapping(uint256 transactionIndex => mapping(address owner => bool confirmed)) public isConfirmed;
    mapping(address owner => bool isOwner) public isOwner;
    mapping(uint256 transactionIndex => bool exists) public existingTransactions;

    // events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event TransactionSubmitted(uint256 indexed txId, address indexed to, uint256 value);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionRevoked(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);

    // errors
    error MultiSigWallet_NotAnOwner();
    error MultiSigWallet_TransactionDoesNotExist();
    error MultiSigWallet_TransactionAlreadyExecuted();
    error MultiSigWallet_TransactionAlreadyConfirmed();
    error MultiSigWallet_NotEnoughConfirmations();
    error MultiSigWallet_InvalidOwnerAddress();
    error MultiSigWallet_DuplicateOwnerAddress();
    error MultiSigWallet_InvalidRequiredConfirmations();
    error MultiSigWallet_TransactionNotConfirmed();
    error MultiSigWallet_TransactionExecutionFailed();
    error MultiSigWallet_OwnersRequired();


    // modifiers
    modifier onlyOwner() {
        if(!isOwner[msg.sender]) {
            revert MultiSigWallet_NotAnOwner();
        }
        _;
    }

    modifier transactionExists(uint256 transactionIndex) {
        if(!existingTransactions[transactionIndex]) {
            revert MultiSigWallet_TransactionDoesNotExist();
        }
        _;
    }

    modifier notExecuted(uint256 transactionIndex) {
        if(transactions[transactionIndex].executed) {
            revert MultiSigWallet_TransactionAlreadyExecuted();
        }
        _;
    }

    modifier notConfirmed(uint256 transactionIndex) {
        if(isConfirmed[transactionIndex][msg.sender]) {
            revert MultiSigWallet_TransactionAlreadyConfirmed();
        }
        _;
    }

    // constructor
    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        if(_owners.length == 0) {
            revert MultiSigWallet_OwnersRequired();
        }
        if(_requiredConfirmations == 0 || _requiredConfirmations > _owners.length) {
            revert MultiSigWallet_InvalidRequiredConfirmations();
        }
        for (uint256 i = 0; i < _owners.length; i++) {
            if(_owners[i] == address(0)) {
                revert MultiSigWallet_InvalidOwnerAddress();
            }
            if(isOwner[_owners[i]]) {
                revert MultiSigWallet_DuplicateOwnerAddress();
            }
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    // fallback function to accept ether
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(address destination, uint256 value, bytes calldata data) external onlyOwner {
        transactions[transactionCount] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false,
            confirmationCount: 0
        });
        emit TransactionSubmitted(transactionCount, destination, value);
        existingTransactions[transactionCount] = true;
        transactionCount++;
    }

    function confirmTransaction(uint256 transactionIndex) 
        external 
        onlyOwner 
        transactionExists(transactionIndex) 
        notExecuted(transactionIndex) 
        notConfirmed(transactionIndex) 
    {
        transactions[transactionIndex].confirmationCount++;
        isConfirmed[transactionIndex][msg.sender] = true;
        emit TransactionConfirmed(transactionIndex, msg.sender);
    }

    function revokeConfirmation(uint256 transactionIndex) external onlyOwner transactionExists(transactionIndex) notExecuted(transactionIndex) {
        if(!isConfirmed[transactionIndex][msg.sender]) {
            revert MultiSigWallet_TransactionNotConfirmed();
        }
        transactions[transactionIndex].confirmationCount--;
        isConfirmed[transactionIndex][msg.sender] = false;
        emit TransactionRevoked(transactionIndex, msg.sender);
    }

    function executeTransaction(uint256 transactionIndex) 
        external 
        onlyOwner 
        transactionExists(transactionIndex) 
        notExecuted(transactionIndex)
        
    {
        if(transactions[transactionIndex].confirmationCount < requiredConfirmations) {
            revert MultiSigWallet_NotEnoughConfirmations();
        }
        Transaction storage txn = transactions[transactionIndex];
        txn.executed = true;

        (bool success, ) = txn.destination.call{value: txn.value}(txn.data);
        if(!success) {
            revert MultiSigWallet_TransactionExecutionFailed();
        }

        emit TransactionExecuted(transactionIndex);
    }

    function getTransactionCount() external view returns (uint256) {
        return transactionCount;
    }

    function getTransaction(uint256 transactionIndex) 
        external 
        view 
        transactionExists(transactionIndex) 
        returns (
            address destination, 
            uint256 value, 
            bytes memory data, 
            bool executed,
            uint256 confirmationCount
        ) 
    {
        Transaction storage txn = transactions[transactionIndex];
        return (txn.destination, txn.value, txn.data, txn.executed, txn.confirmationCount);
    }
    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}