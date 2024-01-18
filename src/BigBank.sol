// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;
import "./Bank.sol";



contract BigBank is Bank {
    address ownerContract;
    error NotOwner();
    error NotEnough();

    constructor(address _ownerContract) {
        ownerContract = _ownerContract; 
    }


    modifier onlyHighValueUser(uint baseAmount) {
        if (msg.value < baseAmount) {
            revert NotEnough();
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != ownerContract) {
            revert NotOwner();
        }
        _;
    }


    function deposit() public payable override onlyHighValueUser(0.0001 ether) {
        super.deposit();
    }


    function withdraw() public override onlyOwner {
        (bool ret, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!ret) {
            revert TransferFailed();
        }
    }






}