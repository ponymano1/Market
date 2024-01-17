// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ITokenRecipient {
    function tokenRecived(address _from, address _to, uint256 _value, bytes memory data) external;
}

contract NFTMarket is IERC721Receiver, ITokenRecipient {
    using SafeERC20 for IERC20;

    IERC20 private immutable _token;
    IERC721 private immutable _nft;

    mapping(uint256 => uint256) private _prices;
    mapping(uint256 => address) private _owners;

    error NotOwner(address addr);
    error NotApproved(uint256 tokenId);
    error NotListed(uint256 tokenId);
    error NotEnoughToken(uint256 value, uint256 price);

    event List(uint256 indexed tokenId, address from, uint256 price);
    event Sold(uint256 indexed tokenId, address from, address to, uint256 price);

    constructor(IERC20 token_, IERC721 nft_) {
        _token = token_;
        _nft = nft_;
    }

    function onERC721Received(address, address, uint256, bytes calldata) pure external override 
        returns (bytes4) {
        return this.onERC721Received.selector;
    }

    modifier OnlyNFTOwner(uint256 tokenId) {
        if (_nft.ownerOf(tokenId) != msg.sender) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    modifier OnlyListed(uint256 tokenId) {
        if (_prices[tokenId] == 0) {
            revert NotListed(tokenId);
        }
        _;
    }

    function list(uint256 tokenId, uint256 price) public {
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _prices[tokenId] = price;
        _owners[tokenId] = msg.sender;
        emit List(tokenId, msg.sender, price);
    }

    function getPrice(uint256 tokenId) public view returns (uint256) {
        return _prices[tokenId];
    }

    function getOwner(uint256 tokenId) public view returns (address) {
        return _owners[tokenId];
    }

    function buy(uint256 tokenId) public OnlyListed(tokenId) {
        uint256 price = _prices[tokenId];
        address owner = _owners[tokenId];
        _prices[tokenId] = 0;
        _owners[tokenId] = address(0);
        _token.safeTransferFrom(msg.sender, owner, price);

        _nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit Sold(tokenId, owner, msg.sender, price);
    }

    function tokenRecived(address _from, address, uint256 _value, bytes memory data) public override {
        // do something
        uint256 tokenId = abi.decode(data, (uint256));
        uint256 price = _prices[tokenId];
        address owner = _owners[tokenId];
        if (_value < price) {
            revert NotEnoughToken(_value, price);
        }
        _prices[tokenId] = 0;
        _owners[tokenId] = address(0);

        _nft.safeTransferFrom(address(this), _from, tokenId);
        _token.safeTransfer(owner, price);
        _token.safeTransfer(_from, _value - price);
    }
}
