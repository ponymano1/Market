// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IStakeETHToken.sol";

abstract contract StakeETHToken is  Ownable, IStakeETHToken, ERC20Permit{
    struct StakeInfo {
        uint256 earnPerShare;//最后一次操作的累积利率
        uint256 earns; //已经结算的收益
    }
    mapping(address => StakeInfo) internal _stakeInfos;

    constructor(address admin_) ERC20("SETH", "SETH") ERC20Permit("SETH") Ownable(admin_) {
        
    }
    
    function mint(address account, uint256 value) public override onlyOwner() {
        _mint(account, value);
        emit Mint(account, value);
    }

    function burn(address account, uint256 value) public onlyOwner() {
        _burn(account, value);
        emit Burn(account, value);
    }
    
    function nonces(address owner) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    function getStakeInfo(address account) public view returns (StakeInfo memory) {
        return _stakeInfos[account];
    }

    function updateStakeInfo(address account, StakeInfo memory stakeInfo) public onlyOwner() {
        _stakeInfos[account] = stakeInfo;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _stakeInfos[to] = _stakeInfos[from];
        _stakeInfos[from] = StakeInfo(0, 0);
        return super.transferFrom(from, to, value);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        address from = msg.sender;
        _stakeInfos[to] = _stakeInfos[from];
        _stakeInfos[from] = StakeInfo(0, 0);       
        return super.transfer(to, value);
    }

}