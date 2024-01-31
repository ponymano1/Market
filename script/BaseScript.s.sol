// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

abstract contract BaseScript is Script {
    address internal deployer;

    function setUp() public virtual {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.rememberKey(deployerPrivateKey);
        
      // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    function saveContract(string memory network, string memory name, address addr) public {
      string memory json1 = "key";
      string memory finalJson =  vm.serializeAddress(json1, "address", addr);
      string memory dirPath = string.concat(string.concat("output/", network), "/");
      vm.writeJson(finalJson, string.concat(dirPath, string.concat(name, ".json"))); 
    }

    modifier broadcaster() {
        vm.startBroadcast(deployer);
        _;
        vm.stopBroadcast();
    }
}