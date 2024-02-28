// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;
import '../src/v2-core/UniswapV2Pair.sol';

import {Test, console} from "forge-std/Test.sol";

contract GenHashTest is Test {
    
    function test_GenHash() public {
        bytes32 hashData = keccak256(type(UniswapV2Pair).creationCode);
        console.log("hashData:");
        console.logBytes32(hashData);
        //将这个hash更改到v2-periphery/libraries/UniswapV2Library.sol中的create2ForPair函数中PairFor方法中
    }
}