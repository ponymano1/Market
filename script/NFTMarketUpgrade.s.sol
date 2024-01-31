import "forge-std/Script.sol";
import  "./BaseScript.s.sol";

import { Upgrades, Options } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { NFTMarket } from "../src/NFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract NFTMarketUpgradeScript is BaseScript {
    address public token = 0x8464135c8F25Da09e49BC8782676a84730C318bC;
    address public nft = 0xbCF26943C0197d2eE0E5D05c716Be60cc2761508;

    function run() public broadcaster {
      Options memory opts;
    //   opts.unsafeSkipAllChecks = true;
        opts.unsafeSkipAllChecks = true;
        address proxy = Upgrades.deployTransparentProxy(
            "NFTMarket.sol",
            deployer,   // INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(NFTMarket.initialize, (IERC20(token),IERC721(nft),"NFTMarket","0.0.1")),         // abi.encodeCall(MyContract.initialize, ("arguments for the initialize function")
            opts
            );

            bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
            address admin = address(uint160(uint256(bytes32(vm.load(address(proxy), ADMIN_SLOT)))));
            console.logBytes32(vm.load(address(proxy), ADMIN_SLOT));
            console.log("NftMarket v1 deployed on %s", address(proxy));
            console.log("Contract admin:", admin);
    }
}