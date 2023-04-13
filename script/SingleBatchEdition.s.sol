// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {SingleBatchEdition} from "contracts/SingleBatchEdition.sol";

contract DeploySingleBatchEdition is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.broadcast(pk);
        SingleBatchEdition edition = new SingleBatchEdition{salt: 0}();
        console.log("SingleBatchEdition address:", address(edition));
    }
}
