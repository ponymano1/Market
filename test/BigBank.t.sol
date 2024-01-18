// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {BigBank} from "../src/BigBank.sol";
import {OwnerContract} from "../src/OwnerContract.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BigBankMock is BigBank {
    mapping(address => uint256) private usersDeposit;
    address[] usersList;

    constructor(address _ownerContract) BigBank(_ownerContract) {
    }

    function deposit_() public payable  {
        super.deposit();
        if (usersDeposit[msg.sender] == 0) {
            usersList.push(msg.sender);
        }
        usersDeposit[msg.sender] += msg.value;
    }

}

contract BigBankTest is Test {
    using Strings for uint256;
    address admin;
    BigBankMock bigBank;
    OwnerContract ownerContract;
    address[20] users;

    function setUp() public {
        admin = makeAddr("admin");
        vm.startPrank(admin);
        {
            ownerContract = new OwnerContract();
            bigBank = new BigBankMock(address(ownerContract));
            ownerContract.setBankAddress(address(bigBank));
        }
        vm.stopPrank();
        for (uint i = 0; i < 20; i++) {
            users[i] = makeAddr(i.toString());
        }
    }

    function testFuzz_Deposit(uint256 i, uint256 amount) public {
        vm.assume(i >= 0 && i < 20);
        vm.assume(amount > 0.0001 ether);
        uint256 amountBefore = bigBank.getBalance(users[i]);
        deposit(users[i], amount, false);
        uint256 amountAfter = bigBank.getBalance(users[i]);

        assertEq(amountAfter, amount + amountBefore, "expect correct amount");
        
        checkTop3();

    }

    function deposit(address user, uint256 amount, bool needRevert) private {
        vm.deal(user, amount);
        vm.startPrank(user);
        {
            if (needRevert) {
                vm.expectRevert();
                bigBank.deposit_{value: amount}();
            } else {
                bigBank.deposit_{value: amount}();
            }
            
        }
        vm.stopPrank();
    }
    
    mapping(address => uint256)  top3Balance;

    function checkTop3() private {
        address[3] memory top3 = bigBank.getHighValueAddresses();
        address minAddr = top3[0];
        uint256 minAmount = bigBank.getBalance(top3[0]);
        for (uint i = 0; i < 3; i++) {
            if (bigBank.getBalance(top3[i]) == 0) {
                continue;
            }
            top3Balance[top3[i]] = bigBank.getBalance(top3[i]);
            if (bigBank.getBalance(top3[i]) < minAmount) {
                minAddr = top3[i];
                minAmount = bigBank.getBalance(top3[i]);
            }
        }

        if (minAmount == 0) {
            return;
        }

        for (uint i = 0; i < 20; i++) {
            if (top3Balance[users[i]] > 0) {
                continue;
            }

            assertLe(bigBank.getBalance(users[i]), minAmount, "expect user balance less than top3");
        }
    }





}