// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IStakeETHToken is IERC20Permit{
    event Mint(address account, uint256 value);
    event Burn(address account, uint256 value);

    function mint(address account, uint256 value) external;
    function burn(address account, uint256 value) external;
    

}