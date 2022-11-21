// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

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

    function makeAddresses(uint256 n) public returns (bytes memory addresses) {
        for (uint256 i = 0; i < n; i++) {
            address addr_i = makeAddr(
                string(abi.encodePacked("addr", LibString.toString(i)))
            );
            addresses = abi.encodePacked(addresses, addr_i);
        }
    }

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        uint256 N = 200;

        string memory name = string.concat(
            "batchy test #",
            LibString.toString(N)
        );
        editionImpl = new SingleBatchEdition();
        ISingleBatchEdition edition = createEdition(name, owner);

        console2.log(name);
        console2.log("Edition address:", address(edition));
        bytes memory recipients = makeAddresses(N);
        edition.mintBatch(recipients);

        vm.stopBroadcast();
    }
}
