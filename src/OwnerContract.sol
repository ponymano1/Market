// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

interface IBigBank {
    function deposit() external payable;
    function withdraw() external;
    function getBalance() external view returns (uint256);
    function getHighValueAddresses() external view returns (address[3] memory);
    function getTotalAmount() external view returns (uint256);

}

contract OwnerContract {
    address private owner;
    address private bigBankAddress;
    error NotOwner();
    error TransferFailed();


    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    receive() external payable {
        
    }

    function setBankAddress(address _bigBankAddress) public onlyOwner {
        bigBankAddress = _bigBankAddress;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function withdrawAllFromBank() public onlyOwner {
        IBigBank(bigBankAddress).withdraw() ;
        
    }

    function withdrawToOwner() public onlyOwner {
        (bool ret, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!ret) {
            revert TransferFailed();
        }
    }

    function getTop3() view public returns (address[3] memory) {
        return IBigBank(bigBankAddress).getHighValueAddresses();
    }
}