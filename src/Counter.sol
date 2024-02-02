// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Counter {
    uint256 public number;
    error TESTREVERT();

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }

    function tryRevert() public pure {
        revert TESTREVERT();
    }  

    function tryRevert2() public pure {
        revert("hahahahhahahahahahahahha");
    } 
}
