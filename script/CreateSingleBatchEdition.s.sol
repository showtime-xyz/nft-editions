// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {Addresses} from "contracts/utils/Addresses.sol";
import {LibString} from "contracts/utils/LibString.sol";
import {ISingleBatchEdition} from "contracts/interfaces/ISingleBatchEdition.sol";
import {SingleBatchEdition} from "contracts/SingleBatchEdition.sol";

contract CreateSingleBatchEdition is Script, Test {
    SingleBatchEdition editionImpl;

    function createEdition(string memory name, address minter)
        internal
        returns (ISingleBatchEdition _edition)
    {
        bytes32 salt = keccak256(abi.encodePacked(name));

        _edition = ISingleBatchEdition(
            ClonesUpgradeable.cloneDeterministic(address(editionImpl), salt)
        );

        _edition.initialize(
            minter,
            name,
            "BATCH",
            "batchy batchy",
            "",
            "ipfs://QmfDdgDMLtXxy3MMR77qNkT9bCHqDfs9pjKFLz46karTa8",
            1000,
            minter
        );
    }

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        uint256 N = 1000;

        string memory name = string.concat(
            "batchy test #",
            LibString.toString(N)
        );
        editionImpl = new SingleBatchEdition();
        ISingleBatchEdition edition = createEdition(name, owner);

        console2.log(name);
        console2.log("Edition address:", address(edition));

        // 🏆 v1: outlined SSTORE2 tx (6474048 gas total for N=1000, 6.5k per mint)
        bytes memory recipients = Addresses.make(N);
        address pointer = SSTORE2.write(recipients); // 4377877 gas for N=1000
        edition.mintBatch(pointer); // 2096171 gas for N=1000

        // v2: inline SSTORE2 tx
        // edition.mintBatch(recipients); // 6556515 gas for N=1000

        vm.stopBroadcast();
    }
}
