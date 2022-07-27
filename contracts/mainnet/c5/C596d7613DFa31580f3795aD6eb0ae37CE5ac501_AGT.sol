// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./erc20.sol";
contract AGT is ERC20{
    address public owner;
    address public minter;

    constructor() ERC20("ATM Governance Token", "AGT", 18){
        owner = msg.sender;
    }
    
    function setOwner(address user) external{
        require(msg.sender == owner, "GTA: only owner");
        require(user != address(0), "user address cannot be 0");
        owner = user;
    }
   
    function setMinter(address user) external{
        require(msg.sender == owner, "GTA: only owner");
        require(user != address(0), "user address cannot be 0");
        minter = user;
    }

    function mint(address to, uint256 value) external{
        require(msg.sender == minter, "GTA: only minter");
        _mint(to, value);
    }
    
    function burn(uint256 amount) external{
        _burn(amount);
    }
}