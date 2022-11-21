// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {LibString} from "contracts/utils/LibString.sol";
import {OwnedInitializable} from "contracts/solmate-initializable/auth/OwnedInitializable.sol";
import {ISingleBatchEdition} from "contracts/interfaces/ISingleBatchEdition.sol";
import {SingleBatchEdition} from "contracts/SingleBatchEdition.sol";

import "contracts/interfaces/Errors.sol";

contract BatchMinter {
    function mintBatch(ISingleBatchEdition edition, bytes calldata addresses)
        public
    {
        edition.mintBatch(addresses);
    }
}

contract SingleBatchEditionTest is Test {
    event Initialized();
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    address internal editionOwner;
    address internal bob;

    ISingleBatchEdition internal editionImpl;
    ISingleBatchEdition internal edition;
    BatchMinter internal minter;

    bytes internal addresses_0001;
    bytes internal addresses_0010;
    bytes internal addresses_0100;
    bytes internal addresses_0300;
    bytes internal addresses_0500;
    bytes internal addresses_1000;

    function makeAddresses(uint256 n) public returns (bytes memory addresses) {
        for (uint256 i = 0; i < n; i++) {
            address addr_i = makeAddr(
                string(abi.encodePacked("addr", LibString.toString(i)))
            );
            addresses = abi.encodePacked(addresses, addr_i);
        }
    }

    function createEdition(string memory name)
        internal
        returns (ISingleBatchEdition _edition)
    {
        bytes32 salt = keccak256(abi.encodePacked(name));

        vm.prank(editionOwner);
        _edition = ISingleBatchEdition(
            ClonesUpgradeable.cloneDeterministic(address(editionImpl), salt)
        );

        _edition.initialize(
            editionOwner,
            name,
            "SYMBOL",
            "description",
            "https://animation.url",
            "https://image.url",
            1000,
            address(minter)
        );
    }

    function setUp() public {
        editionOwner = makeAddr("editionOwner");
        bob = makeAddr("bob");

        editionImpl = new SingleBatchEdition();
        minter = new BatchMinter();

        edition = createEdition("edition");

        addresses_0001 = makeAddresses(1);
        addresses_0010 = makeAddresses(10);
        addresses_0100 = makeAddresses(100);
        addresses_0300 = makeAddresses(300);
        addresses_0500 = makeAddresses(500);
        addresses_1000 = makeAddresses(1000);
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONAL TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructorEmitsInitializedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Initialized();
        new SingleBatchEdition();
    }

    function testNoOwnerAfterConstructor() public {
        SingleBatchEdition newImpl = new SingleBatchEdition();
        assertEq(OwnedInitializable(address(newImpl)).owner(), address(0));
    }

    function testInitializerEmitsOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), editionOwner);
        createEdition("testInitializerEmitsOwnershipTransferredEvent");
    }

    function testDoesNotAllowReinitializationOfTheImplContract() public {
        SingleBatchEdition newImpl = new SingleBatchEdition();

        vm.expectRevert("ALREADY_INITIALIZED");
        newImpl.initialize(
            editionOwner,
            "name",
            "SYMBOL",
            "description",
            "https://animation.url",
            "https://image.url",
            1000,
            editionOwner
        );
    }

    function testDoesNotAllowReinitializationOfProxyContracts() public {
        vm.expectRevert("ALREADY_INITIALIZED");
        edition.initialize(
            editionOwner,
            "name",
            "SYMBOL",
            "description",
            "https://animation.url",
            "https://image.url",
            1000,
            editionOwner
        );
    }

    function testTransferOwnershipFailsForBob() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        OwnedInitializable(address(edition)).transferOwnership(bob);
    }

    function testTransferOwnershipWorksForOwner() public {
        vm.prank(editionOwner);
        OwnedInitializable(address(edition)).transferOwnership(bob);
        assertEq(OwnedInitializable(address(edition)).owner(), bob);
    }

    // TODO: withdraw auth
    // TODO: mintBatch auth

    /*//////////////////////////////////////////////////////////////
                               GAS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev for gas snapshot
    function testMintBatchViaContract_0001() public {
        minter.mintBatch(edition, addresses_0001);
    }

    /// @dev for gas snapshot
    function testMintBatchViaContract_0010() public {
        minter.mintBatch(edition, addresses_0010);
    }

    /// @dev for gas snapshot
    function testMintBatchViaContract_0100() public {
        minter.mintBatch(edition, addresses_0100);
    }

    /// @dev for gas snapshot
    function testMintBatchViaContract_1000() public {
        minter.mintBatch(edition, addresses_1000);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0001() public {
        vm.prank(address(minter));
        edition.mintBatch(addresses_0001);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0010() public {
        vm.prank(address(minter));
        edition.mintBatch(addresses_0010);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0100() public {
        vm.prank(address(minter));
        edition.mintBatch(addresses_0100);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0300() public {
        vm.prank(address(minter));
        edition.mintBatch(addresses_0300);
    }

    function testMintBatchDirect_0500() public {
        vm.prank(address(minter));
        edition.mintBatch(addresses_0500);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_1000() public {
        vm.prank(address(minter));
        edition.mintBatch(addresses_1000);
    }
}
