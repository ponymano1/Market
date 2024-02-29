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
import "./v2-periphery/interfaces/IUniswapV2Router02.sol";
import "./v2-periphery/interfaces/IWETH.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";







interface ITokenRecipient {
    function tokenRecived(address _from, address _to, uint256 _value, bytes memory data) external;
}
/**
support two kinds of buy and list
1. permit and buy
2. buy by signature
*/
contract NFTMarketWETH is  IERC721Receiver, EIP712, Nonces, Multicall {
    using SafeERC20 for IERC20;
    using Math for uint256;
    address internal immutable UNISWAP_V2_ROUTER;
    address internal immutable WETH;
    address internal KKToken;//交易用token
    
    
    IERC721 private  _nft;

    address private _admin;

    //real fee rate = _feeRates / DOMINATOR
    uint256 private _feeRates;
    uint256 public constant DOMINATOR = 10000;

    //累计的手续费
    uint256 internal totalFee;

    mapping(uint256 => uint256) private _prices;
    mapping(uint256 => address) private _owners;



    bytes32 internal whiteListRoot = 0xb63cec15d66cdcc08199c64a2105f32356c226151d1d1b43a6e9d68fb2e7684f;
    
    uint256 internal cumulativeEarnPerShare; //当前的累积利率
    uint256 internal lastCalcInterestBlockNum;//上一次计算累计利率的块高
    uint256 internal totalStakeAmount; //总的质押量
    uint256 public constant RATIO = 10 * 8;

    struct StakeInfo {
        uint256 stakeAmount;
        uint256 lastEarnPerShare;//最后一次操作的累积利率
        uint256 earns; //已经结算的收益
    }

    mapping(address => StakeInfo) internal _stakeInfos;

    error NotOwner(address addr);
    error NotApproved(uint256 tokenId);
    error NotListed(uint256 tokenId);
    error NotEnoughToken(uint256 value, uint256 price);
    error ErrorSignature();
    error Expired();
    error NotAdmin();
    error NotPermitBuyer();
    error NotEnoughStake();
    error NotEnough();

    event List(uint256 indexed tokenId, address from, uint256 price);
    event Sold(uint256 indexed tokenId, address from, address to, uint256 price);


    constructor(IERC721 nft_, address uniswapRouterAddr, address wethAddr,string memory name_, string memory version_, uint256 feeRates_, address stakeETHToken_) EIP712(name_, version_) {
        _nft = nft_;
        _admin = msg.sender;   
        UNISWAP_V2_ROUTER = uniswapRouterAddr;   
        WETH = wethAddr; 
        _feeRates = feeRates_;
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

    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    function list(uint256 tokenId, uint256 price) public {
        _nft.safeTransferFrom(msg.sender, address(this), tokenId);
        _prices[tokenId] = price;
        _owners[tokenId] = msg.sender;
        emit List(tokenId, msg.sender, price);
    }

    function buy(uint256 tokenId) public OnlyListed(tokenId) {
        uint256 price = _prices[tokenId];
        address owner = _owners[tokenId];
        _prices[tokenId] = 0;
        _owners[tokenId] = address(0);
        uint256 fee = Math.mulDiv(price, _feeRates, DOMINATOR);
        
        uint256 amount = price - fee;
        IERC20(KKToken).safeTransferFrom(msg.sender, owner, amount);
        IERC20(KKToken).safeTransferFrom(msg.sender, address(this), fee);
        totalFee += fee;

        _nft.safeTransferFrom(address(this), msg.sender, tokenId);
        
        updateCumulativeEarnPerShare(fee);
        emit Sold(tokenId, owner, msg.sender, price);
    }

    function stake(uint256 amountOfWETH) public {
        //updateCumulativeEarnPerShare(0);
        IERC20(WETH).safeTransferFrom(msg.sender, address(this), amountOfWETH);
        uint256 amountStake = amountOfWETH / RATIO;
        updateStakeInfo(amountStake, true);
        totalStakeAmount += amountStake;
    } 

    function unStake(uint256 amount) public {
        updateStakeInfo(amount, false);
        totalStakeAmount -= amount;
        uint256 earn = _stakeInfos[msg.sender].earns;
        _stakeInfos[msg.sender].earns -= earn;
        uint256 amountWETH = amount * RATIO;
        IERC20(WETH).safeTransfer(msg.sender, amountWETH);
    }

    function getStakeEarns() public view returns (uint256) {
        return _stakeInfos[msg.sender].earns;
    }

    function claimStakeEarns(uint256 amount) public {
        if (amount > _stakeInfos[msg.sender].earns) {
            revert NotEnough();
        }
        _stakeInfos[msg.sender].earns -= amount;
        IERC20(KKToken).safeTransfer(msg.sender, amount);
    }

    function updateStakeInfo(uint256 amount, bool isAdd) private {
        if (isAdd == false && _stakeInfos[msg.sender].stakeAmount < amount) {
            revert NotEnoughStake();
        }
        uint256 preStakeAmount = _stakeInfos[msg.sender].stakeAmount;
        uint256 earnPerShareInterval = cumulativeEarnPerShare - _stakeInfos[msg.sender].lastEarnPerShare;
        uint256 earn = preStakeAmount * earnPerShareInterval;
        _stakeInfos[msg.sender].earns += earn;
        _stakeInfos[msg.sender].stakeAmount = isAdd ? preStakeAmount + amount : preStakeAmount - amount;
        _stakeInfos[msg.sender].lastEarnPerShare = cumulativeEarnPerShare;
    }
    
    function updateCumulativeEarnPerShare(uint256 feeAmount) private {
        //获取区块高度
        uint256 curBlockNumber = block.number;
        
        if (lastCalcInterestBlockNum == curBlockNumber) {
            return;
        }
        
        //一个区块的利率 totalFee/ totalSupply
        uint256 earnPerShare = getCurrentEarnPerShare(feeAmount);

        //计算当前的累计
        cumulativeEarnPerShare += earnPerShare;
        lastCalcInterestBlockNum = curBlockNumber;
    }

    function updateStakeInfo() private {

    }



    function getCurrentEarnPerShare(uint256 feeAmount) public view returns (uint256) {
        if (totalStakeAmount == 0) {
            return 0;
        }
        return totalFee / totalStakeAmount;
    }

    function getAmountsIn(IERC20 tokenIn, uint256 price) public view returns (uint256) {
        if (address(tokenIn) == WETH) {
            return price;
        }

        address[] memory path;
        path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(WETH);
    
        uint256[] memory amounts = IUniswapV2Router02(UNISWAP_V2_ROUTER).getAmountsIn(price, path);
        return amounts[0];
    }

  

    function swapTokenTo(IERC20 tokenIn, uint256 amountInMax, uint256 amountOut,address to, uint256 deadline) internal {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountInMax);
        IERC20(tokenIn).approve(UNISWAP_V2_ROUTER, amountInMax);

        address[] memory path;
        
        path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(WETH);

        
        
        IUniswapV2Router02(UNISWAP_V2_ROUTER).swapTokensForExactTokens(
            amountOut,
            amountInMax,
            path,
            to,
            deadline
        );

  
    }

    function swapTokenAndBuyNFT(IERC20 tokenIn, uint256 amountInMax, uint256 tokenId,uint256 deadline) OnlyListed(tokenId) public {
        uint256 price = _prices[tokenId];
        address owner = _owners[tokenId];
        _prices[tokenId] = 0;
        _owners[tokenId] = address(0);

        uint256 balanceBefore = IERC20(WETH).balanceOf(owner);
        swapTokenTo(tokenIn, amountInMax, price, owner, deadline);
        uint256 balanceAfter = IERC20(WETH).balanceOf(owner);
        if (balanceAfter < price + balanceBefore) {
            revert NotEnoughToken(balanceAfter - balanceBefore, price);
        }
        _nft.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Sold(tokenId, owner, msg.sender, price);
        
    }
    
}
