// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

abstract contract Bank {
    mapping(address => uint256) private balances;
    address[3] private highValueAddresses;
    error TransferFailed();


    constructor() {
        
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable virtual{
        balances[msg.sender] += msg.value;
        updateHighValueAddresses();

    }

    function withdraw() public virtual;

    function updateHighValueAddresses() private {
        uint minAmount = balances[msg.sender];
        uint minIndex = 1 << 255 - 1;
        for (uint i = 0; i < 3; i++) {
            if ( highValueAddresses[i] == msg.sender) {
                return;
            }

            if (balances[highValueAddresses[i]] < minAmount) {
                minIndex = i;
                minAmount = balances[highValueAddresses[i]];
            }
        }

        if (minIndex < 3) {
            highValueAddresses[minIndex] = msg.sender;
        }  
    }
    

    function getBalance(address addr) public view returns (uint256) {
        return balances[addr];
    }

    function getHighValueAddresses() public view returns (address[3] memory) {
        return highValueAddresses;
    }

    function getTotalAmount() public view returns (uint256) {
        return address(this).balance;
    }

    


}