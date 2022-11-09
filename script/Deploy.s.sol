// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

import {EditionCreator} from "contracts/EditionCreator.sol";
import {Edition} from "contracts/Edition.sol";

contract Deploy is Script, Test {
    address constant EDITION_IMPL = 0xeaC9Da3f23c03daA069161e888f106c18Ee0453A;
    address constant EDITION_CREATOR =
        0x0000006dCEFEC877F5d845d455A7a41348118dd5;

    /// @dev returns the hash of the init code (creation code + ABI-encoded args) used in CREATE2
    function initCodeHash(bytes memory creationCode, bytes memory args)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(creationCode, args));
    }

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        Edition editionImpl = new Edition{salt: 0}();
        assertEq(address(editionImpl), EDITION_IMPL);

        console2.log("EditionCreator initCodeHash:");
        console2.logBytes32(
            initCodeHash(
                type(EditionCreator).creationCode,
                abi.encode(address(editionImpl))
            )
        );

        EditionCreator creator = new EditionCreator{
            salt: 0x0000000000000000000000000000000000000000000000000000000000032cf4
        }(address(editionImpl));
        assertEq(address(creator), EDITION_CREATOR);
        console2.log("EditionCreator address:", address(creator));

        vm.stopBroadcast();
    }
}
