// SPDX-License-Identifier: MIT
pragma solidity ^0.8;


import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyERC721 is ERC721URIStorage {
    uint256 private tokenIds;

    constructor (string memory name_, string memory symbol_) ERC721(name_, symbol_) {

    }

    function mint(address to, string memory tokenURI) public returns (uint256) {
        tokenIds++;
        uint256 tokenId = tokenIds;
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        return tokenId;
        
    }
    

}