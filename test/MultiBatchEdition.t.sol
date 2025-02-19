// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {console2} from "forge-std/console2.sol";

import {SSTORE2} from "solmate/utils/SSTORE2.sol";

import {Addresses} from "SS2ERC721/../test/helpers/Addresses.sol";

import {LibString} from "contracts/utils/LibString.sol";
import {OwnedInitializable} from "contracts/solmate-initializable/auth/OwnedInitializable.sol";
import {IBatchEdition} from "contracts/interfaces/IBatchEdition.sol";
import {MultiBatchEdition, ERC721} from "contracts/MultiBatchEdition.sol";

import {EditionBaseSpec, EditionConfig, EditionConfigWither} from "test/common/EditionBaseSpec.t.sol";

import "contracts/interfaces/Errors.sol";

contract BatchMinter {
    function mintBatch(IBatchEdition edition, bytes calldata addresses) public returns (uint256) {
        return edition.mintBatch(addresses);
    }

    function mintBatch(IBatchEdition edition, address startAddr, uint256 num) public returns (uint256) {
        return edition.mintBatch(Addresses.make(startAddr, num));
    }
}

contract MultiBatchEditionTest is EditionBaseSpec {
    using Addresses for uint256;
    using EditionConfigWither for EditionConfig;

    IBatchEdition internal edition;

    address internal bob;

    BatchMinter internal minterContract;

    /*//////////////////////////////////////////////////////////////
                          BASE SPEC OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // bob has no special rights
        bob = makeAddr("bob");

        edition = IBatchEdition(_edition);
    }

    function createImpl() internal override returns (address) {
        return address(new MultiBatchEdition());
    }

    /// @dev create a clone of editionImpl with the given config
    function create(EditionConfig memory config, bytes memory expectedError) internal override returns (address) {
        address newEdition = super.create(config, expectedError);

        // lazy initialization of the minter
        if (address(minterContract) == address(0)) {
            minterContract = new BatchMinter();
        }

        // only continue if we were not expecting an error
        if (expectedError.length == 0) {
            vm.prank(editionOwner);
            IBatchEdition(newEdition).setApprovedMinter(address(minterContract), true);
        }

        return newEdition;
    }

    function _mint(address _edition, bytes memory recipients, address msgSender, bytes memory expectedError)
        internal
        returns (uint256 tokenId)
    {
        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        vm.prank(msgSender);
        return IBatchEdition(_edition).mintBatch(recipients);
    }

    function mint(address _edition, address to, address msgSender, bytes memory expectedError)
        internal
        override
        returns (uint256 tokenId)
    {
        return _mint(_edition, abi.encodePacked(to), msgSender, expectedError);
    }

    function mint(address _edition, uint256 num, address msgSender, bytes memory expectedError) internal override {
        _mint(_edition, Addresses.make(num), msgSender, expectedError);
    }

    /*//////////////////////////////////////////////////////////////
                            FUNCTIONAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mintBatch_canNotMint0() public {
        mint(_edition, 0, approvedMinter, "INVALID_ADDRESSES");
    }

    function test_mintBatch_canNotAfterIncompleteBatch() public {
        minterContract.mintBatch(edition, abi.encodePacked(address(this)));

        vm.expectRevert("INCOMPLETE_BATCH");
        minterContract.mintBatch(edition, abi.encodePacked(address(this)));
    }

    function test_mintBatch_canNotMintBadData() public {
        vm.expectRevert("INVALID_ADDRESSES");
        minterContract.mintBatch(edition, "beep boop");
    }

    function test_getPrimaryOwnersPointer_nullBeforeMint() public {
        assertEq(edition.getPrimaryOwnersPointer(0), address(0));
    }

    function test_getPrimaryOwnersPointer_setAfterMint() public {
        minterContract.mintBatch(edition, abi.encodePacked(address(this)));

        address pointer = edition.getPrimaryOwnersPointer(0);
        bytes memory data = SSTORE2.read(pointer);
        assertEq(data.length, 20);
    }

    function test_isPrimaryOwner() public {
        minterContract.mintBatch(edition, abi.encodePacked(address(this)));

        // we are a primary owner (the only one in fact), as well as a current owner
        assertTrue(edition.isPrimaryOwner(address(this)));

        // bob is neither
        assertFalse(edition.isPrimaryOwner(bob));

        // when we transfer the NFT out
        ERC721(_edition).transferFrom(address(this), bob, 1);

        // then we are no longer a current owner, but we are still a primary owner
        assertTrue(edition.isPrimaryOwner(address(this)));

        // and bob is a current owner, but was never a primary owner
        assertFalse(edition.isPrimaryOwner(bob));
    }

    function test_isPrimaryOwner_fuzz(uint32 num, uint32 index) public {
        vm.assume(num > 0);

        num = uint32(bound(num, 1, 1228));
        index = uint32(bound(index, 0, num - 1));

        MultiBatchEdition openEdition = MultiBatchEdition(_openEdition);

        address startAddr = address(1);
        minterContract.mintBatch(openEdition, Addresses.make(startAddr, num));

        address randomPrimaryOwner = address(uint160(startAddr) + index);
        uint256 tokenId = index + 1;

        // both a primary and a current owner
        assertTrue(openEdition.isPrimaryOwner(randomPrimaryOwner));
        assertEq(openEdition.balanceOf(randomPrimaryOwner), 1);
        assertEq(openEdition.ownerOf(tokenId), randomPrimaryOwner);

        // bob is neither
        assertFalse(openEdition.isPrimaryOwner(bob));

        // when we transfer the NFT out
        vm.prank(randomPrimaryOwner);
        openEdition.transferFrom(randomPrimaryOwner, bob, tokenId);

        // then no longer a current owner, but still a primary owner
        assertTrue(openEdition.isPrimaryOwner(randomPrimaryOwner));
        assertEq(openEdition.balanceOf(randomPrimaryOwner), 0);

        // and bob is a current owner, but was never a primary owner
        assertEq(openEdition.ownerOf(tokenId), bob);
        assertEq(openEdition.balanceOf(bob), 1);
        assertFalse(openEdition.isPrimaryOwner(bob));
    }

    function test_e2e_multiBatch() public {
        uint256 batchSize = 1228;
        uint256 editionSize = 2000;

        IBatchEdition edition2k = IBatchEdition(create(DEFAULT_CONFIG.withName("Y2K").withEditionSize(editionSize), ""));

        minterContract.mintBatch(edition2k, Addresses.make(address(1), batchSize));

        // we can't mint more than the edition size
        bytes memory secondBatchTooBig = Addresses.make((batchSize + 1).to_addr(), editionSize - batchSize + 1);

        vm.expectRevert(abi.encodeWithSelector(SoldOut.selector));
        vm.prank(approvedMinter);
        edition2k.mintBatch(secondBatchTooBig);

        // but we can mint exactly the edition size
        bytes memory secondBatch = Addresses.make((batchSize + 1).to_addr(), editionSize - batchSize);
        vm.prank(approvedMinter);
        edition2k.mintBatch(secondBatch);

        assertEq(edition2k.totalSupply(), editionSize);
    }

    function test_e2e_1M() public {
        MultiBatchEdition edition1M = MultiBatchEdition(_openEdition);

        uint256 ONE_MILLION = 1_000_000;
        uint256 leftToMint = ONE_MILLION;
        address startAddr = address(1);
        uint256 batchSize = 1228;

        while (leftToMint > 0) {
            uint256 thisBatch = leftToMint > batchSize ? batchSize : leftToMint;
            uint256 numMinted = minterContract.mintBatch(edition1M, startAddr, thisBatch);
            assertEq(numMinted, thisBatch);

            leftToMint -= thisBatch;
            startAddr = (uint160(startAddr) + thisBatch).to_addr();
        }

        assertEq(edition1M.totalSupply(), ONE_MILLION);
        assertEq(edition1M.ownerOf(ONE_MILLION), ONE_MILLION.to_addr());
     }
}
