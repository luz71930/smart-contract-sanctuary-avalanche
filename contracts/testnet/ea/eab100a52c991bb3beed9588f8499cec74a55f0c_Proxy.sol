/**
 *Submitted for verification at testnet.snowtrace.io on 2022-02-11
*/

// File: contracts/Proxy.sol

pragma solidity 0.6.12;

contract Proxy {
    // Code position in storage is keccak256("PROXIABLE") = "0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7"
    uint256 constant PROXIABLE_MEM_SLOT = 0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7;
    // constructor(bytes memory constructData, address contractLogic) public {
    constructor(address contractLogic) public {
        // Verify a valid address was passed in
        require(contractLogic != address(0), "Contract Logic cannot be 0x0");

        // save the code address
        assembly { // solium-disable-line
            sstore(PROXIABLE_MEM_SLOT, contractLogic)
        }
    }

    fallback() external payable {
        assembly { // solium-disable-line
            let contractLogic := sload(PROXIABLE_MEM_SLOT)
            let ptr := mload(0x40)
            calldatacopy(ptr, 0x0, calldatasize())
            let success := delegatecall(gas(), contractLogic, ptr, calldatasize(), 0, 0)
            let retSz := returndatasize()
            returndatacopy(ptr, 0, retSz)
            switch success
            case 0 {
                revert(ptr, retSz)
            }
            default {
                return(ptr, retSz)
            }
        }
    }
}