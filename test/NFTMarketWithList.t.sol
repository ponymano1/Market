// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";

import {NFTMarketWithList} from "../src/NFTMarketWithList.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract NFTMarketTest is Test {
    MyERC20  myERC20;
    MyERC721  myERC721;
    NFTMarketWithList  nftMarket;
    

    address  admin;
    address  seller1;
    address  buyer1;

    function setUp() public {
        admin = makeAddr("myAdmin");
        seller1 = makeAddr("seller1");
        buyer1 = makeAddr("buyer1");

        vm.startPrank(admin);
        {
            myERC20 = new MyERC20("MyERC20", "MYE");
            myERC721 = new MyERC721("MyERC721", "MYNFT");
            nftMarket = new NFTMarketWithList(myERC20, myERC721);
        }
        vm.stopPrank();
    }



    function  test_ListNFT() public {
        vm.startPrank(seller1);
        {
            uint256 nftToken1 = myERC721.mint(seller1, "s1_Nft_3");
            uint256 nftToken2 = myERC721.mint(seller1, "s1_Nft_4");
            myERC721.approve(address(nftMarket), nftToken1);
            nftMarket.listEx(nftToken1, 100);
            myERC721.approve(address(nftMarket), nftToken2);
            nftMarket.listEx(nftToken2, 200);
            assertEq(nftMarket.getPrice(nftToken1), 100, "expect correct price");
            assertEq(myERC721.ownerOf(nftToken1), address(nftMarket), "expect nftMarket is owner");
            uint256[] memory tokens = nftMarket.listAllTokens();
            assertEq(tokens.length, 2, "expect 2 tokens");
            for (uint256 i = 0; i < tokens.length; i++) {
                console.log("token:", tokens[i]);
            }

        }
        vm.stopPrank();
    }




    function buyNFT(address buyer, address seller, uint256 nftTokenId, uint256 erc20Amount, bool needRevert) internal {
        vm.startPrank(buyer);
        myERC20.mint(buyer, erc20Amount);
        myERC20.approve(address(nftMarket), erc20Amount);
        uint256 price = nftMarket.getPrice(nftTokenId);
        uint256 buyerBalanceBefore = myERC20.balanceOf(buyer);
        uint256 sellerBalanceBefore = myERC20.balanceOf(seller);
        
        if (needRevert) {
            vm.expectRevert();
            nftMarket.buy(nftTokenId);
             vm.stopPrank();
            return;
        }
        nftMarket.buy(nftTokenId);
  

        uint256 buyerBalanceAfter = myERC20.balanceOf(buyer);
        uint256 sellerBalancAfter = myERC20.balanceOf(seller);
        // console.log("buyerBalanceBefore", buyerBalanceBefore);
        // console.log("buyerBalanceAfter", buyerBalanceAfter);
        // console.log("sellerBalanceBefore", sellerBalanceBefore);
        // console.log("sellerBalancAfter", sellerBalancAfter);
        // console.log("nftMarket addre", address(nftMarket));
        // console.log("owner:", myERC721.ownerOf(nftTokenId));
        assertEq(myERC721.ownerOf(nftTokenId), buyer, "expect nft owner is transfer to buyer");
        assertEq(buyerBalanceBefore- buyerBalanceAfter, price, "expect buyer pay price");
        assertEq(sellerBalancAfter - sellerBalanceBefore, price, "expect seller receive price");

        vm.stopPrank();
    }

    function buyNFTViaTransfer(address buyer, address seller, uint256 nftTokenId, uint256 erc20Amount) internal {
        vm.startPrank(buyer);
        myERC20.mint(buyer, erc20Amount);
        uint256 price = nftMarket.getPrice(nftTokenId);
        uint256 buyerBalanceBefore = myERC20.balanceOf(buyer);
        uint256 sellerBalanceBefore = myERC20.balanceOf(seller);

        myERC20.transferToAndCallback(address(nftMarket), erc20Amount, abi.encode(nftTokenId));

        uint256 buyerBalanceAfter = myERC20.balanceOf(buyer);
        uint256 sellerBalancAfter = myERC20.balanceOf(seller);

        assertEq(myERC721.ownerOf(nftTokenId), buyer, "expect nft owner is transfer to buyer");
        assertEq(buyerBalanceBefore- buyerBalanceAfter, price, "expect buyer pay erc20Amount");
        assertEq(sellerBalancAfter - sellerBalanceBefore, price, "expect seller receive erc20Amount");

        vm.stopPrank();
    }



}

