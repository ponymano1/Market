// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Nonces.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./v2-periphery/interfaces/IUniswapV2Router02.sol";
import "./v2-periphery/interfaces/IWETH.sol";


import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
// import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
// import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";




interface ITokenRecipient {
    function tokenRecived(address _from, address _to, uint256 _value, bytes memory data) external;
}
/**
support two kinds of buy and list
1. permit and buy
2. buy by signature
*/
contract NFTMarketEx is  IERC721Receiver, ITokenRecipient, EIP712, Nonces, Multicall {
    using SafeERC20 for IERC20;
    address internal immutable UNISWAP_V2_ROUTE;
    address internal immutable WETH;
    
    IERC20 private  _token;
    IERC721 private  _nft;

    address private _admin;

    mapping(uint256 => uint256) private _prices;
    mapping(uint256 => address) private _owners;

    bytes32 internal whiteListRoot = 0xb63cec15d66cdcc08199c64a2105f32356c226151d1d1b43a6e9d68fb2e7684f;


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

    constructor(IERC20 token_, IERC721 nft_, address uniswapRouterAddr, address wethAddr,string memory name_, string memory version_) EIP712(name_, version_) {
        _token = token_;
        _nft = nft_;
        _admin = msg.sender;   
        UNISWAP_V2_ROUTER = uniswapRouterAddr;   
        WETH = wethAddr; 
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
    /**
    if list by signature, the function will not be called
     */
    function list(uint256 tokenId, uint256 price) public {
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _prices[tokenId] = price;
        _owners[tokenId] = msg.sender;
        emit List(tokenId, msg.sender, price);
    }
    /**
    if list by signature, the function will not be called
     */
    function getPrice(uint256 tokenId) public view returns (uint256) {
        return _prices[tokenId];
    }
    /**
    if list by signature, the function will not be called
     */
    function getOwner(uint256 tokenId) public view returns (address) {
        return _owners[tokenId];
    }
    /**
    if list by signature, the function will not be called
     */
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
    
    /**
    only for test 
     */
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
        //这里之前有个bug, 一个地址可以签发多个签名，但是一旦验签，nouce就会增加，其他的就不会验签通过。
        //所以要nouce的key 要seller+tokenId

        bytes32 nonceHash = keccak256(abi.encodePacked(seller, tokenId));
        address nonceAddr = address(uint160(uint256(nonceHash)));

        //bytes32 structHash = keccak256(abi.encode(CHECK_NFT_SIGNER_HASH, tokenId, seller, _useNonce(seller), price));//有bug代码
        
        bytes32 structHash = keccak256(abi.encode(CHECK_NFT_SIGNER_HASH, tokenId, seller, _useNonce(nonceAddr), price));
        console.log("checkNFTSigner structHash:", uint256(structHash));
        bytes32 hash = _hashTypedDataV4(structHash);  
        console.log("checkNFTSigner totalHash:", uint256(hash));
        address signer = ECDSA.recover(hash, v, r, s);
        console.log("checkNFTSigner signer:", signer);
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

    function getNFTContractAddress() public view returns (address) {
        return address(_nft);
    }

    function setMerkleRoot(bytes32 merkleRoot) external {
        if (msg.sender != _admin) {
             revert NotAdmin();
        }
        whiteListRoot = merkleRoot;
    }

    function whitelist(bytes32[] calldata _merkleProof) view public returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verify(_merkleProof, whiteListRoot, leaf);
    }

    function claimNFT(uint256 tokenId, bytes32[] calldata _merkleProof) public {
        uint256 price = _prices[tokenId];
        if (whitelist(_merkleProof)) {
            price = 100;
        }
        address owner = _owners[tokenId];
        _prices[tokenId] = 0;
        _owners[tokenId] = address(0);
        _token.safeTransferFrom(msg.sender, owner, price);
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);
        emit Sold(tokenId, owner, msg.sender, price);
    }

    /**
    only for test and debug
     */
    function erc20PermitAndBuy(uint256 tokenId , uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        uint256 price = _prices[tokenId];
        IERC20Permit(address(_token)).permit(msg.sender, address(this), price, deadline, v, r, s);
        buy(tokenId);
    }

    function erc20Permit(uint256 tokenId , uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        uint256 price = _prices[tokenId];
        IERC20Permit(address(_token)).permit(msg.sender, address(this), price, deadline, v, r, s);
    }

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getAmountsIn(IERC20 tokenIn, uint256 price) public view returns (uint256[] memory) {
        if (tokenIn == _token) {
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = price;
            return amounts;
        }

        address[] memory path;
        if (address(tokenIn) == WETH) {
            path = new address[](2);
            path[0] = WETH;
            path[1] = address(_token);
        } else {
            path = new address[](3);
            path[0] = address(tokenIn);
            path[1] = WETH;
            path[2] = address(_token);
        }
        uint256[] memory amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountsIn(price, path);
        return amounts;
    }

    function swapTokenTo(IERC20 tokenIn, uint256 amountIn, uint256 amountOutMin, address to, uint256 deadline) internal returns(uint256[] memory amounts){
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(UNISWAP_V2_ROUTER, amountIn);

        address[] memory path;
        if (address(tokenIn) == WETH) {
            path = new address[](2);
            path[0] = WETH;
            path[1] = address(_token);

        } else {
            path = new address[](3);
            path[0] = address(tokenIn);
            path[1] = WETH;
            path[2] = address(_token);

        }

        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            to,
            deadline
        ); 
    }

    function swapTokenAndBuyNFT(IERC20 tokenIn, uint256 amountIn, uint256 tokenId,uint256 deadline) OnlyListed(tokenId) public {
        uint256 price = _prices[tokenId];
        address owner = _owners[tokenId];
        _prices[tokenId] = 0;
        _owners[tokenId] = address(0);

        uint256 balanceBefore = _token.balanceOf(owner);
        uint256[] memory amounts = swapTokenTo(tokenIn, amountIn, price, owner, deadline);
        uint256 balanceAfter = _token.balanceOf(owner);
        if (balanceAfter < price + balanceBefore) {
            revert NotEnoughToken(amounts[amounts.length - 1], price);
        }
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Sold(tokenId, owner, msg.sender, price);
        
    }
    
}
