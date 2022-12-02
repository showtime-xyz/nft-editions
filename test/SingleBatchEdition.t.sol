// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ClonesUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {Addresses} from "contracts/utils/Addresses.sol";
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
        minter.mintBatch(edition, Addresses.make(1));
    }

    /// @dev for gas snapshot
    function testMintBatchViaContract_0010() public {
        minter.mintBatch(edition, Addresses.make(10));
    }

    /// @dev for gas snapshot
    function testMintBatchViaContract_0100() public {
        minter.mintBatch(edition, Addresses.make(100));
    }

    /// @dev for gas snapshot
    function testMintBatchViaContract_1000() public {
        minter.mintBatch(edition, Addresses.make(1000));
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0001() public {
        address pointer = SSTORE2.write(Addresses.make(1));
        vm.prank(address(minter));
        edition.mintBatch(pointer);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0010() public {
        address pointer = SSTORE2.write(Addresses.make(10));
        vm.prank(address(minter));
        edition.mintBatch(pointer);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0100() public {
        address pointer = SSTORE2.write(Addresses.make(100));
        vm.prank(address(minter));
        edition.mintBatch(pointer);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0300() public {
        address pointer = SSTORE2.write(Addresses.make(300));
        vm.prank(address(minter));
        edition.mintBatch(pointer);
    }

    function testMintBatchDirect_0500() public {
        address pointer = SSTORE2.write(Addresses.make(500));
        vm.prank(address(minter));
        edition.mintBatch(pointer);
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_1000() public {
        address pointer = SSTORE2.write(Addresses.make(1000));
        vm.prank(address(minter));
        edition.mintBatch(pointer);
    }
}
