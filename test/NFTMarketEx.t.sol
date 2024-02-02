// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketEx} from "../src/NFTMarketEx.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {MyERC2612} from "../src/MyERC2612.sol";

contract NFTMarketExTest is Test {
    NFTMarketEx market;
    MyERC721 nft;
    MyERC2612 token;

    address  admin;
    address  seller1;
    address  buyer1;
    address  buyer2;
    address  buyer3;

    address[] claimArr;

    function setup() public {
        admin = makeAddr("myAdmin");
        seller1 = makeAddr("seller1");
        buyer1 = makeAddr("buyer1");
        buyer2 = makeAddr("buyer2");
        buyer3 = makeAddr("buyer3");
        claimArr.push(buyer1);
        claimArr.push(buyer2);

        vm.startPrank(admin);
        {
            token = new MyERC2612();
            nft = new MyERC721("MyERC721", "MYNFT");
            market = new NFTMarketEx(token, nft, "NFTMarketEx", "1");
            token.transfer(buyer1, 1000);
            token.transfer(buyer2, 1000);
            token.transfer(buyer3, 1000);
        
        }
        vm.stopPrank();
    }
}