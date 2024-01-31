// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
//import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import "@openzeppelin/contracts/access/OwnableUpgradeable.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
//import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";



interface ITokenRecipient {
    function tokenRecived(address _from, address _to, uint256 _value, bytes memory data) external;
}

contract NFTMarket is Initializable, IERC721Receiver, ITokenRecipient, EIP712Upgradeable, NoncesUpgradeable {
    using SafeERC20 for IERC20;

    IERC20 private  _token;
    IERC721 private  _nft;

    address private _admin;

    mapping(uint256 => uint256) private _prices;
    mapping(uint256 => address) private _owners;

    bytes32 private constant SIGN_TYPEHASH = keccak256("signNFTWhiteList(uint256 tokenId,address permitBuyer,uint256 nonce,uint256 deadline)");

    bytes32 private constant CHECK_NFT_SIGNER_HASH = keccak256("checkNFTSigner(uint256 tokenId,address seller,uint256 nonce,uint256 price)");

    error NotOwner(address addr);
    error NotApproved(uint256 tokenId);
    error NotListed(uint256 tokenId);
    error NotEnoughToken(uint256 value, uint256 price);
    error ErrorSignature();
    error Expired();
    error NotAdmin();
    error NotPermitBuyer();

    event List(uint256 indexed tokenId, address from, uint256 price);
    event Sold(uint256 indexed tokenId, address from, address to, uint256 price);

    constructor() {
        //_disableInitializers();
    }

    function initialize(IERC20 token_, IERC721 nft_, string memory name_, string memory version_) initializer public {
        __EIP712_init(name_, version_);
        __Nonces_init();
        _token = token_;
        _nft = nft_;
        _admin = msg.sender;
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

    function name() public view returns (string memory) {
        return _EIP712Name();
    }

    function version() public view returns (string memory) {
        return _EIP712Version();
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

    function permitAndBuy(uint256 tokenId , address permitBuyer , uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        if (msg.sender != permitBuyer) {
             revert NotPermitBuyer();
        }
        checkNFTWhiteList(tokenId, permitBuyer, deadline, v, r, s);
        buy(tokenId);
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
    
    function signNFTWhiteList(uint256 tokenId , address permitBuyer ) public view returns(uint256, bytes32) {
        if (msg.sender != _admin) {
             revert NotAdmin();
        }
        uint256 deadline = block.timestamp + 3600 * 24 * 30;
        bytes32 structHash = keccak256(abi.encode(SIGN_TYPEHASH, tokenId, permitBuyer, nonces(permitBuyer), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);  
        return (deadline, hash); 
    }

    function checkNFTWhiteList(uint256 tokenId , address permitBuyer , uint256 deadline, uint8 v, bytes32 r, bytes32 s) public   {
        uint256 curTime = block.timestamp;
        if (curTime > deadline) {
            revert Expired();
        }
        bytes32 structHash = keccak256(abi.encode(SIGN_TYPEHASH, tokenId, permitBuyer, _useNonce(permitBuyer), deadline));

        bytes32 hash = _hashTypedDataV4(structHash);  
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != permitBuyer) {
            revert ErrorSignature();
        } 

    }

    function checkNFTSigner(uint256 tokenId , address seller, uint256 price, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 structHash = keccak256(abi.encode(CHECK_NFT_SIGNER_HASH, tokenId, seller, _useNonce(seller), price));
        bytes32 hash = _hashTypedDataV4(structHash);  
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != seller) {
            revert ErrorSignature();
        }
    }

    function buyNFTBySig(uint256 tokenId , address seller , uint256 price, uint8 v, bytes32 r, bytes32 s) public {
        if (seller != _nft.ownerOf(tokenId)) {
            revert NotOwner(seller);
        }
        checkNFTSigner(tokenId, seller, price, v, r, s);
        _token.safeTransferFrom(msg.sender, seller, price);
        _nft.safeTransferFrom(seller, msg.sender, tokenId);
        emit Sold(tokenId, seller, msg.sender, price);
    }
    
}
