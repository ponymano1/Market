// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract MyERC2612 is ERC20Permit {
    // Your contract code here
    constructor() ERC20("Token2612", "Token2612") ERC20Permit("Token2612") {
        _mint(msg.sender, 10000 * 10 ** 18);
    }
    
}