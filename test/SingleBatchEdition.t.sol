// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ClonesUpgradeable} from "@openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {Addresses} from "contracts/utils/Addresses.sol";
import {LibString} from "contracts/utils/LibString.sol";
import {OwnedInitializable} from "contracts/solmate-initializable/auth/OwnedInitializable.sol";
import {IBatchEdition} from "contracts/interfaces/IBatchEdition.sol";
import {SingleBatchEdition, ERC721} from "contracts/SingleBatchEdition.sol";

import "contracts/interfaces/Errors.sol";

contract BatchMinter {
    function mintBatch(IBatchEdition edition, bytes calldata addresses)
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

    IBatchEdition internal editionImpl;
    IBatchEdition internal edition;
    BatchMinter internal minter;

    function createEdition(string memory name)
        internal
        returns (IBatchEdition _edition)
    {
        bytes32 salt = keccak256(abi.encodePacked(name));

        vm.prank(editionOwner);
        _edition = IBatchEdition(
            ClonesUpgradeable.cloneDeterministic(address(editionImpl), salt)
        );

        _edition.initialize(
            editionOwner,
            name,
            "SYMBOL",
            "description",
            "https://animation.url",
            "https://image.url",
            0, // editionSize
            10_00, // royaltyBPS
            0 // mintPeriodSeconds
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
            0, // editionSize
            2_50, // royaltyBps
            0 // mintPeriodSeconds
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
            0, // editionSize
            2_50, // royaltyBps
            0 // mintPeriodSeconds
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

    function testMintingUpdatesTotalSupply(uint256 n) public {
        n = bound(n, 1, 1228);
        assertEq(edition.totalSupply(), 0);

        // when we mint n tokens
        minter.mintBatch(edition, Addresses.make(n));

        // then the total supply is n
        assertEq(edition.totalSupply(), n);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        edition.withdraw();
    }

    function testOwnerCanWithdraw() public {
        vm.deal(address(edition), 1 ether);

        // when the owner withdraws from the edition
        vm.prank(editionOwner);
        edition.withdraw();

        // then the funds are transferred
        assertEq(address(edition).balance, 0);
        assertEq(editionOwner.balance, 1 ether);
    }

    function testOnlyMinterCanMint() public {
        bytes memory addresses = Addresses.make(1);
        vm.prank(bob);
        vm.expectRevert(Unauthorized.selector);
        edition.mintBatch(addresses);
    }

    function testCanNotMint0() public {
        vm.expectRevert("INVALID_ADDRESSES");
        minter.mintBatch(edition, "");
    }

    function testCanNotMintTwice() public {
        minter.mintBatch(edition, abi.encodePacked(address(this)));

        vm.expectRevert("ALREADY_MINTED");
        minter.mintBatch(edition, abi.encodePacked(address(this)));
    }

    function testCanNotMintBadData() public {
        vm.expectRevert("INVALID_ADDRESSES");
        minter.mintBatch(edition, "beep boop");
    }

    function test_getPrimaryOwnersPointer_nullBeforeMint() public {
        assertEq(edition.getPrimaryOwnersPointer(0), address(0));
    }

    function test_getPrimaryOwnersPointer_setAfterMint() public {
        minter.mintBatch(edition, abi.encodePacked(address(this)));

        address pointer = edition.getPrimaryOwnersPointer(0);
        bytes memory data = SSTORE2.read(pointer);
        assertEq(data.length, 20);
    }

    function test_isPrimaryOwner() public {
        minter.mintBatch(edition, abi.encodePacked(address(this)));

        // we are a primary owner (the only one in fact), as well as a current owner
        assertTrue(edition.isPrimaryOwner(address(this)));

        // bob is neither
        assertFalse(edition.isPrimaryOwner(bob));

        // when we transfer the NFT out
        ERC721(address(edition)).transferFrom(address(this), bob, 1);

        // then we are no longer a current owner, but we are still a primary owner
        assertTrue(edition.isPrimaryOwner(address(this)));

        // and bob is a current owner, but was never a primary owner
        assertFalse(edition.isPrimaryOwner(bob));
    }

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
        vm.startPrank(address(minter));
        edition.mintBatch(Addresses.make(1));
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0010() public {
        vm.startPrank(address(minter));
        edition.mintBatch(Addresses.make(10));
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0100() public {
        vm.startPrank(address(minter));
        edition.mintBatch(Addresses.make(100));
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_0300() public {
        vm.startPrank(address(minter));
        edition.mintBatch(Addresses.make(300));
    }

    function testMintBatchDirect_0500() public {
        vm.startPrank(address(minter));
        edition.mintBatch(Addresses.make(500));
    }

    /// @dev for gas snapshot
    function testMintBatchDirect_1000() public {
        vm.startPrank(address(minter));
        edition.mintBatch(Addresses.make(1000));
    }
}
