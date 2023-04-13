// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {MultiBatchEdition} from "contracts/MultiBatchEdition.sol";

contract DeployMultiBatchEdition is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        MultiBatchEdition edition = new MultiBatchEdition{salt: 0}();
        console.log("MultiBatchEdition address:", address(edition));
    }
}
