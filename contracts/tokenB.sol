// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenB is ERC20, ERC20Burnable, Ownable {
    constructor(uint256 initialSuppy)
        ERC20("TokenB", "TokenB")
        Ownable(msg.sender)
    {
        _mint(msg.sender, initialSuppy * 10 ** decimals());
    }

    // pass the amount in wei (1eth = 10^18)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

}