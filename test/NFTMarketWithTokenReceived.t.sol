// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket} from "../src/NFTMarketWithTokenReceived.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {MyERC20} from "../src/MyERC20.sol";

contract NFTMarketTest is Test {
    MyERC20 public myERC20;
    MyERC721 public myERC721;
    NFTMarket public nftMarket;
    

    address public admin;
    address public seller1;
    address public buyer1;

    function setUp() public {
        admin = makeAddr("myAdmin");
        seller1 = makeAddr("seller1");
        buyer1 = makeAddr("buyer1");

        vm.startPrank(admin);
        {
            myERC20 = new MyERC20("MyERC20", "MYE");
            myERC721 = new MyERC721("MyERC721", "MYNFT");
            nftMarket = new NFTMarket(myERC20, myERC721);
        }
        vm.stopPrank();
    }

    function test_MintNFT() public {
        vm.startPrank(seller1);
        {
            uint256 token1 = myERC721.mint(seller1, "s1_Nft_1");
            address owner = myERC721.ownerOf(token1);
            assertEq(owner, seller1, "owner should be seller1");
        }
        vm.stopPrank();
    }

    function testFail_ListNFTWithoutApprove() public {
        vm.startPrank(seller1);
        {
            uint256 token = myERC721.mint(seller1, "s1_Nft_2");
            nftMarket.list(token, 100);
        }
        vm.stopPrank();
    }

    function  test_ListNFT() public {
        vm.startPrank(seller1);
        {
            uint256 nftToken = myERC721.mint(seller1, "s1_Nft_3");
            myERC721.approve(address(nftMarket), nftToken);
            nftMarket.list(nftToken, 100);
            assertEq(nftMarket.getPrice(nftToken), 100, "expect correct price");
            assertEq(myERC721.ownerOf(nftToken), address(nftMarket), "expect nftMarket is owner");
        }
        vm.stopPrank();
    }

    function test_BuyNFTViaBuyFunction() public {
        uint256 nftToken = mintAndListNFT(seller1, "test_BuyNFTViaBuyFunction", 100);
        buyNFT(buyer1, seller1 , nftToken, 100);
    }

    function test_BuyNFTViaTransfer() public {
        uint256 nftToken = mintAndListNFT(seller1, "test_BuyNFTViaTransfer", 50);
        buyNFTViaTransfer(buyer1, seller1 , nftToken, 50);
    }


    function testFail_BuyNFTWithoutEnoughToken() public {
        uint256 nftToken = mintAndListNFT(seller1, "testFail_BuyNFTWithoutEnoughToken", 100);
        buyNFT(buyer1, seller1 , nftToken, 50);
    }

    function testFail_BuyNFTAlreadySold() public {
        uint256 nftToken = mintAndListNFT(seller1, "testFail_BuyNFTWithoutList", 100);
        buyNFT(buyer1, seller1 , nftToken, 100);
        buyNFT(buyer1, seller1 , nftToken, 100);
    }

    function testFail_TransferWithoutEnoughToken() public {
        uint256 nftToken = mintAndListNFT(seller1, "testFail_BuyNFTWithoutEnoughToken", 100);
        buyNFT(buyer1, seller1 , nftToken, 50);        
    }

    function test_BalanceCorrectAfterError() public {
        uint256 nftTokenId = mintAndListNFT(seller1, "test_BalanceCorrectAfterError", 100);
        uint256 balanceBuyerBefore = myERC20.balanceOf(buyer1);
        //vm.expectRevert();
        buyNFT(buyer1, seller1, nftTokenId, 50);
        uint256 balanceBuyerAfter = myERC20.balanceOf(buyer1);
        assertEq(balanceBuyerBefore, balanceBuyerAfter);
    }

    function test_BuyWithHigherPrice() public {
        uint256 nftToken = mintAndListNFT(seller1, "test_BuyWithHigherPrice", 100);
        buyNFT(buyer1, seller1 , nftToken, 200);
    }

    function test_BuyWithHigherPriceViaTransfer() public {
        uint256 nftToken = mintAndListNFT(seller1, "test_BuyWithHigherPriceViaTransfer", 100);
        buyNFTViaTransfer(buyer1, seller1 , nftToken, 200);
    }


    function mintAndListNFT(address seller, string memory url, uint256 price) internal returns(uint256){
        vm.startPrank(seller);
        uint256 nftToken = myERC721.mint(seller, url);
        myERC721.approve(address(nftMarket), nftToken);
        nftMarket.list(nftToken, price);
        assertEq(nftMarket.getPrice(nftToken), price, "expect correct price");
        assertEq(myERC721.ownerOf(nftToken), address(nftMarket), "expect nftMarket is owner");
        assertEq(nftMarket.getOwner(nftToken), seller, "expect nftMarket can store who is the seller");
        vm.stopPrank();
        return nftToken;
    }


    function buyNFT(address buyer, address seller, uint256 nftTokenId, uint256 erc20Amount) internal {
        vm.startPrank(buyer);
        myERC20.mint(buyer, erc20Amount);
        myERC20.approve(address(nftMarket), erc20Amount);
        uint256 price = nftMarket.getPrice(nftTokenId);
        uint256 buyerBalanceBefore = myERC20.balanceOf(buyer);
        uint256 sellerBalanceBefore = myERC20.balanceOf(seller);
        
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

