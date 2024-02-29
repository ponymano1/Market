// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketEx} from "../src/NFTMarketEx.sol";
import {MyERC721} from "../src/MyERC721.sol";
import {MyERC2612} from "../src/MyERC2612.sol";
import "../src/SigUtil.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../src/v2-periphery/interfaces/IUniswapV2Router02.sol";
import "../src/v2-periphery/interfaces/IWETH.sol";
//import "../src/interface/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";


contract NFTMarketExTest is Test {
    using Math for uint256;
    bytes32 private constant CHECK_NFT_SIGNER_HASH = keccak256("checkNFTSigner(uint256 tokenId,address seller,uint256 nonce,uint256 price)");
    address internal constant UNISWAP_V2_ROUTER = 0x214691F90394E1e66A4514767177333f8f9f44fF;
    address internal  WETH = 0x399C99956f715C8392a965bC44dcCB58863cBc11;
    NFTMarketEx nftMarket;
    MyERC721 myERC721;
    MyERC2612 token;
    MyERC2612 otherToken;
    SigUtils internal sigUtils;

    uint256  adminPk;
    uint256  seller1Pk;
    uint256  seller2Pk;
    uint256  buyer1Pk;
    uint256  buyer2Pk;
    uint256  buyer3Pk;


    address  admin;
    address  seller1;
    address  seller2;
    address  buyer1;
    address  buyer2;
    address  buyer3;

    address[] claimArr;

    struct NFTSigInfo{
        uint256 tokenId;
        address seller;
        uint256 nonce;
        uint256 price;
        uint256 deadline;
        bytes32 sig;
    }

    function setUp() public {
        adminPk = 0x6E11E;
        seller1Pk = 0x6E11E;
        seller2Pk = 0x5E11E;
        buyer1Pk = 0x7E11E;
        buyer2Pk = 0x8E11E;
        buyer3Pk = 0x9E11E;
  
        admin = vm.addr(adminPk);
        seller1 = vm.addr(seller1Pk);
        seller2 = vm.addr(seller2Pk);
        buyer1 = vm.addr(buyer1Pk);
        buyer2 = vm.addr(buyer2Pk);
        buyer3 = vm.addr(buyer3Pk);
        
        

        claimArr.push(buyer1);
        claimArr.push(buyer2);

        
        grantWETH(admin, 8000 ether);

        vm.startPrank(admin);
        {
            token = new MyERC2612();
            myERC721 = new MyERC721("MyERC721", "MYNFT");
            nftMarket = new NFTMarketEx(token, myERC721, UNISWAP_V2_ROUTER, WETH, "NFTMarketEx", "1");
            otherToken = new MyERC2612();
            //给buyer1 ether
            vm.deal(buyer1, 10 ether);
            vm.deal(buyer2, 10 ether);
            vm.deal(buyer3, 10 ether);
            vm.deal(admin, 1000 ether);

            token.transfer(buyer1, 1000 ether);
            token.transfer(buyer2, 1000 ether);
            token.transfer(buyer3, 1000 ether);

            
            addLiquidity();

            sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        }
        vm.stopPrank();
        
        
    }

    function test_BuyNFTWithApprove() public {
        uint256 nftToken = 0;
        vm.startPrank(seller1);
        {
            nftToken = myERC721.mint(seller1, "s1_Nft_1");
            myERC721.approve(address(nftMarket), nftToken);
            nftMarket.list(nftToken, 10 * 10 ** 18);
            assertEq(nftMarket.getPrice(nftToken), 10 * 10 ** 18, "expect correct price");
            assertEq(myERC721.ownerOf(nftToken), address(nftMarket), "expect nftMarket is owner");
        }
        vm.stopPrank();
        uint256 price = nftMarket.getPrice(nftToken);

        buyNFT(buyer1, seller1, nftToken, price, false);
    }

    function test_BuyWithERC20Permit() public {
        uint256 nftToken = 0;
        vm.startPrank(seller1);
        {
            nftToken = myERC721.mint(seller1, "s1_Nft_2");
            myERC721.approve(address(nftMarket), nftToken);
            nftMarket.list(nftToken, 10 * 10 ** 18);
            assertEq(nftMarket.getPrice(nftToken), 10 * 10 ** 18, "expect correct price");
            assertEq(myERC721.ownerOf(nftToken), address(nftMarket), "expect nftMarket is owner");
        }
        vm.stopPrank();
        
        uint256 price = nftMarket.getPrice(nftToken);
        uint256 deadline = block.timestamp + 10000;
        
        vm.startPrank(buyer1);
        {
            SigUtils.Permit memory permit = SigUtils.Permit({
                owner: buyer1,
                spender: address(nftMarket),
                value: price,
                nonce: token.nonces(buyer1),
                deadline: deadline
            });

            bytes32 digest = sigUtils.getTypedDataHash(permit);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyer1Pk, digest);
            
            uint256 buyerBalanceBefore = token.balanceOf(buyer1);
            uint256 sellerBalanceBefore = token.balanceOf(seller1);  

            nftMarket.erc20PermitAndBuy(nftToken, deadline, v, r, s);

            uint256 buyerBalanceAfter = token.balanceOf(buyer1);
            uint256 sellerBalanceAfter = token.balanceOf(seller1); 

            assertEq(myERC721.ownerOf(nftToken), buyer1, "expect nft owner is transfer to buyer");
            assertEq(buyerBalanceBefore- buyerBalanceAfter, price, "expect buyer pay price");
            assertEq(sellerBalanceAfter - sellerBalanceBefore, price, "expect seller receive price");

        }
        vm.stopPrank();        
    }

    function test_BuyWithSig() public {
        uint256 nftToken = 0;
        uint256 price = 5 * 10 ** 18;
        uint8 v;
        bytes32 r;
        bytes32 s;


        vm.startPrank(seller1);
        {
            nftToken = myERC721.mint(seller1, "s1_Nft_3");
            myERC721.approve(address(nftMarket), nftToken);
            bytes32 nonceHash = keccak256(abi.encodePacked(seller1, nftToken));
            address nonceAddr = address(uint160(uint256(nonceHash)));
            uint256 nonce = nftMarket.nonces(nonceAddr);
            //bytes32 structHash = keccak256(abi.encode(CHECK_NFT_SIGNER_HASH, tokenId, seller, _useNonce(seller), price));
            bytes32 structHash = keccak256(abi.encode(CHECK_NFT_SIGNER_HASH, nftToken, seller1, nonce, price));//有bug代码
            console.log("list structHash:", uint256(structHash));
       // bytes32 structHash = keccak256(abi.encode(CHECK_NFT_SIGNER_HASH, tokenId, seller, _useNonce(nonceAddr), price));
            bytes32 hash = _hashTypedDataV4(structHash); 
            console.log("total hash:", uint256(hash));
            (v, r, s) = vm.sign(seller1Pk, hash);
        }
        vm.stopPrank();

        vm.startPrank(buyer2);
        {
            uint256 buyerBalanceBefore = token.balanceOf(buyer2);
            uint256 sellerBalanceBefore = token.balanceOf(seller1);
            token.approve(address(nftMarket), price);

            nftMarket.buyNFTBySig(nftToken, seller1, price, v, r, s);

            uint256 buyerBalanceAfter = token.balanceOf(buyer2);
            uint256 sellerBalanceAfter = token.balanceOf(seller1);

            assertEq(myERC721.ownerOf(nftToken), buyer2, "expect nft owner is transfer to buyer");
            assertEq(buyerBalanceBefore- buyerBalanceAfter, price, "expect buyer pay price");
            assertEq(sellerBalanceAfter - sellerBalanceBefore, price, "expect seller receive price");
        }
        vm.stopPrank();

    }


    function buyNFT(address buyer, address seller, uint256 nftTokenId, uint256 erc20Amount, bool needRevert) internal {
        vm.startPrank(buyer);
        //token.mint(buyer, erc20Amount);
        token.approve(address(nftMarket), erc20Amount);
        uint256 price = nftMarket.getPrice(nftTokenId);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        
        if (needRevert) {
            vm.expectRevert();
            nftMarket.buy(nftTokenId);
             vm.stopPrank();
            return;
        }
        nftMarket.buy(nftTokenId);
  

        uint256 buyerBalanceAfter = token.balanceOf(buyer);
        uint256 sellerBalancAfter = token.balanceOf(seller);
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

    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        bytes32 domainSeparator = nftMarket.DOMAIN_SEPARATOR();
        console.log("list domainSeparator:", uint256(domainSeparator));
        return MessageHashUtils.toTypedDataHash(domainSeparator, structHash);
    }

    function test_swapTokenAndBuyNFT() public {
        uint256 nftToken = 0;
        vm.startPrank(seller1);
        {
            nftToken = myERC721.mint(seller1, "s1_Nft_4");
            myERC721.approve(address(nftMarket), nftToken);
            nftMarket.list(nftToken, 2 ether);
            assertEq(nftMarket.getPrice(nftToken), 2 ether, "expect correct price");
            assertEq(myERC721.ownerOf(nftToken), address(nftMarket), "expect nftMarket is owner");
        }
        vm.stopPrank();
        
        uint256 price = nftMarket.getPrice(nftToken);
        grantWETH(buyer1, 10 ether);
        vm.startPrank(buyer1);
        {
            uint256 balanceOfSellerBefore = token.balanceOf(seller1);
            uint256[] memory amountsIn = nftMarket.getAmountsIn(IERC20(WETH), price);
            for (uint256 i = 0; i < amountsIn.length; i++) {
                console.log("test_swapTokenAndBuyNFT: amountsIn: i=", i, " amountsIn[i]=",amountsIn[i]);
            }
            uint256 amountIn = amountsIn[0];
            uint256 amountInMax = amountIn + amountIn.mulDiv(5, 100);
            IERC20(WETH).approve(address(nftMarket), amountInMax);
            console.log("test_swapTokenAndBuyNFT: amountIn:", amountIn, " amountInMax:", amountInMax);
            nftMarket.swapTokenAndBuyNFT(IERC20(WETH), amountInMax, nftToken, block.timestamp + 10000);
            //nftMarket.swapTokenAndBuyNFT(nftToken, 10 * 10 ** 18);
            uint256 balanceOfSellerAfter = token.balanceOf(seller1);
            console.log("test_swapTokenAndBuyNFT: received amount:", balanceOfSellerAfter - balanceOfSellerBefore, " price:", price);
            assertEq(myERC721.ownerOf(nftToken), buyer1, "expect nft owner is transfer to buyer");
            if (balanceOfSellerAfter - balanceOfSellerBefore == price) {
                console.log("test_swapTokenAndBuyNFT: received amount:", balanceOfSellerAfter - balanceOfSellerBefore, " price:", price);
            } else {
                revert();
            }
        }
        vm.stopPrank();
        
    }

    function grantWETH(address to, uint256 amount) internal {
        vm.startPrank(to);
        {
            vm.deal(to, amount);
            IWETH(WETH).deposit{value: amount}();
        }
        vm.stopPrank();
    }

    function addLiquidity() internal {
        vm.startPrank(admin);
        {
            token.approve(UNISWAP_V2_ROUTER, 1000 ether);
            otherToken.approve(UNISWAP_V2_ROUTER, 1000 ether);
            IERC20(WETH).approve(UNISWAP_V2_ROUTER, 1000 ether);
            IUniswapV2Router02(UNISWAP_V2_ROUTER).addLiquidity(address(token), address(WETH), 500 ether , 100 ether , 1, 1, address(this), block.timestamp + 10000);
            IUniswapV2Router02(UNISWAP_V2_ROUTER).addLiquidity(address(otherToken), address(WETH), 500 ether, 100 ether, 1, 1, address(this), block.timestamp + 10000);
        }
        vm.stopPrank();
    }
}