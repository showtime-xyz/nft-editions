// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {Edition} from "contracts/Edition.sol";

contract DeployEdition is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        Edition edition = new Edition{salt: 0}();
        console.log("Edition address:", address(edition));
    }
}
