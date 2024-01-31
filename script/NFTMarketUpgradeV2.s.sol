import "forge-std/Script.sol";
import  "./BaseScript.s.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { NFTMarket } from "../src/NFTMarket.sol";
import { NFTMarketV2 } from "../src/NFTMarketV2.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract NFTMarketUpgradeScript is BaseScript {
    address public token = 0x8464135c8F25Da09e49BC8782676a84730C318bC;
    address public nft = 0xbCF26943C0197d2eE0E5D05c716Be60cc2761508;

    function run() public broadcaster {
      Options memory opts;
    //   opts.unsafeSkipAllChecks = true;
        opts.unsafeSkipAllChecks = true;
        opts.referenceContract = "NFTMarket.sol";
        Upgrades.upgradeProxy(0x5370F78c6af2Da9cF6642382A3a75F9D5aEc9cc1,"NFTMarketV2.sol", "", opts);
    }
}