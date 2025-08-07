// contracts/TokenB.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenB is IERC20 {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function setMinter(address minter, bool status) external;
}
contract TokenB is ERC20, Ownable, ITokenB {
    mapping(address => bool) public isMinter;

    constructor() ERC20("Token B", "TKB") Ownable(msg.sender) {}

    // errors
    error TokenB_NotMinter();
    error TokenB_ZeroAmount();

    //modifiers
    modifier onlyMinter() {
        if (!isMinter[msg.sender]) revert TokenB_NotMinter();
        _;
    }

    function setMinter(address minter, bool status) external onlyOwner {
        isMinter[minter] = status;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        if (amount == 0) revert TokenB_ZeroAmount();
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        if (amount == 0) revert TokenB_ZeroAmount();
        _burn(from, amount);
    }
}
