// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./NFTMarketWithTokenReceived.sol"; 


contract NFTMarketWithList is NFTMarket {
    uint[] internal _tokenIds;

    constructor(IERC20 token_, IERC721 nft_) NFTMarket(token_, nft_) {
    }

    function listEx(uint256 tokenId, uint256 price) public {
        super.list(tokenId, price);
        _tokenIds.push(tokenId);
    }

    function listAllTokens() public view returns (uint[] memory) {
        return _tokenIds;
    }

}