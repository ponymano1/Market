// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTMarket} from "../src/NFTMarketWithTokenReceived.sol";

contract NFTMarketScript is Script {
    string ERC20Addr  = "0x8464135c8F25Da09e49BC8782676a84730C318bC";
    string NFTAddr    = "0xbCF26943C0197d2eE0E5D05c716Be60cc2761508";
    function setUp() public {
        // console.log("NFTMarketScript setUp");
        // NFTMarket market = new NFTMarket(ERC20Addr, NFTAddr);
    }

    function run() public {
        vm.broadcast();
    }
}
