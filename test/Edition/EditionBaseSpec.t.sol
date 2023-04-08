// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {EditionBase, IEditionBase} from "contracts/common/EditionBase.sol";
import {IOwned} from "contracts/solmate-initializable/auth/IOwned.sol";

import {EditionMetadataTests} from "test/Edition/EditionMetadataTests.t.sol";

import "test/Edition/fixtures/EditionFixture.sol";

function newIntegerOverflow(uint256 value) pure returns (bytes memory) {
    return abi.encodeWithSelector(IntegerOverflow.selector, value);
}

abstract contract EditionBaseSpec is EditionMetadataTests {
    using EditionConfigWither for EditionConfig;

    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function setUp() public virtual override {
        _editionImpl = createImpl();
        _edition = create();
        _openEdition = create(DEFAULT_CONFIG.withName("Open Edition").withEditionSize(0));
        _timeLimitedEdition =
            create(DEFAULT_CONFIG.withName("Time Limited Edition").withMintPeriod(2 days).withEditionSize(0));

        EditionMetadataTests.setUp();
    }


    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR / INITIALIZER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor_emitsInitializedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Initialized();
        createImpl();
    }

    function test_constructor_newImplHasNoOwner() public {
        address newImpl = createImpl();
        assertEq(IOwned(newImpl).owner(), address(0));
    }

    function test_initializer_emitsOwnershipTransferred() public {
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), editionOwner);
        create(DEFAULT_CONFIG.withName("test_initializer_emitsOwnershipTransferred"));
    }

    function test_constructor_doesNotAllowReinitialization() public {
        address newImpl = createImpl();

        vm.expectRevert("ALREADY_INITIALIZED");
        IEditionBase(newImpl).initialize(
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

    function test_initializer_doesNotAllowReinitialization() public {
        vm.expectRevert("ALREADY_INITIALIZED");
        IEditionBase(_edition).initialize(
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

    function test_clone_duplicateReverts() public {
        create(DEFAULT_CONFIG.withName("duplicate"));

        vm.expectRevert();
        create(DEFAULT_CONFIG.withName("duplicate"));
    }

    function test_initialize_editionSizeOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        EditionConfig memory config = DEFAULT_CONFIG.withEditionSize(tooBig).withName("Edition Size Too Big");

        create(config, newIntegerOverflow(tooBig));
    }

    function test_initialize_mintPeriodOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        EditionConfig memory config = DEFAULT_CONFIG.withMintPeriod(tooBig).withName("Mint Period Too Big");

        create(config, newIntegerOverflow(tooBig + block.timestamp));
    }

    function test_initialize_royaltiesOverflow() public {
        uint256 tooBig = uint256(type(uint16).max) + 1;
        EditionConfig memory config = DEFAULT_CONFIG.withRoyaltiesBps(tooBig).withName("Royalties Too Big");

        create(config, newIntegerOverflow(tooBig));
    }

    /*//////////////////////////////////////////////////////////////
                          ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferOwnership_onlyOwnerFail(address passerBy) public {
        vm.assume(passerBy != editionOwner);

        vm.expectRevert("UNAUTHORIZED");
        vm.prank(passerBy);
        IOwned(_edition).transferOwnership(passerBy);
    }

    function test_transferOwnership_onlyOwnerPass(address newOwner) public {
        vm.prank(editionOwner);
        IOwned(_edition).transferOwnership(newOwner);
        assertEq(IOwned(_edition).owner(), newOwner);
    }

    function test_withdraw_onlyOwnerFail(address passerBy) public {
        vm.assume(passerBy != editionOwner);

        // when somebody else tries to withdraw, it reverts
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(passerBy);
        IEditionBase(_edition).withdraw();
    }

    function test_withdraw_onlyOwnerPass() public {
        vm.deal(_edition, 1 ether);

        // when the owner withdraws from the edition
        vm.prank(editionOwner);
        IEditionBase(_edition).withdraw();

        // then the funds are transferred
        assertEq(_edition.balance, 0);
        assertEq(editionOwner.balance, 1 ether);
    }

    function test_setApprovedMinter_onlyOwnerFail(address passerBy) public {
        vm.assume(passerBy != editionOwner);

        // when somebody else tries to set an approved minter, it reverts
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(passerBy);
        IEditionBase(_edition).setApprovedMinter(passerBy, true);
    }

    function test_setApprovedMinter_onlyOwnerPass(address newMinter) public {
        // when the owner sets an approved minter
        vm.prank(editionOwner);
        IEditionBase(_edition).setApprovedMinter(newMinter, true);

        // then the approved minter is set
        assertEq(IEditionBase(_edition).isApprovedMinter(newMinter), true);
    }

    function test_setOperatorFilter_onlyOwnerFail(address passerBy) public {
        vm.assume(passerBy != editionOwner);

        // when somebody else tries to set an operator filter, it reverts
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(passerBy);
        IEditionBase(_edition).setOperatorFilter(passerBy);
    }

    function test_setOperatorFilter_onlyOwnerPass(address newFilter) public {
        // when the owner sets an operator filter
        vm.prank(editionOwner);
        IEditionBase(_edition).setOperatorFilter(newFilter);

        // then the operator filter is set
        assertEq(EditionBase(_edition).activeOperatorFilter(), newFilter);
    }

    function test_enableDefaultOperatorFilter_onlyOwnerFail(address passerBy) public {
        vm.assume(passerBy != editionOwner);

        // when somebody else tries to enable the default operator filter, it reverts
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(passerBy);
        IEditionBase(_edition).enableDefaultOperatorFilter();
    }

    function test_enableDefaultOperatorFilter_onlyOwnerPass() public {
        // when the owner enables the default operator filter
        vm.prank(editionOwner);
        IEditionBase(_edition).enableDefaultOperatorFilter();

        // then the operator filter is set
        assertEq(
            EditionBase(_edition).activeOperatorFilter(),
            address(EditionBase(_edition).CANONICAL_OPENSEA_SUBSCRIPTION())
        );
    }

    /*//////////////////////////////////////////////////////////////
                               MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mint_updatesTotalSupply(address to) public {
        vm.assume(to != address(0));

        assertEq(IEditionBase(_edition).totalSupply(), 0);

        // when we mint 1 token
        mint(_edition, to);

        // then the total supply is n
        assertEq(IEditionBase(_edition).totalSupply(), 1);
    }

    function test_mint_updatesTotalSupply(uint256 n) public {
        n = bound(n, 1, 1000);

        assertEq(IEditionBase(_openEdition).totalSupply(), 0);

        // when we mint n tokens
        mint(_openEdition, n);

        // then the total supply is n
        assertEq(IEditionBase(_openEdition).totalSupply(), n);
    }

    function test_mint_checksAuth(address nonApproved) public {
        vm.assume(nonApproved != approvedMinter);
        vm.assume(nonApproved != editionOwner);

        bytes memory expectedError = abi.encodeWithSelector(Unauthorized.selector);

        // minting a single token fails
        mint(_edition, nonApproved, nonApproved, expectedError);

        // minting multiple tokens fails
        mint(_edition, 42, nonApproved, expectedError);
    }

    /*//////////////////////////////////////////////////////////////
                               BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferFrom_toBurnAddress() public {
        uint256 tokenId = mint(_edition, address(this));

        // no burn method, burning is done by transfering to the burn address
        IERC721(_edition).transferFrom(address(this), BURN_ADDRESS, tokenId);

        // as a result, totalSupply is unchanged
        assertEq(EditionBase(_edition).totalSupply(), 1);

        // and the token is owned by the burn address
        assertEq(IERC721(_edition).ownerOf(tokenId), BURN_ADDRESS);
    }

    function test_transferFrom_unapprovedReverts(address unapproved) public {
        vm.assume(unapproved != address(this));

        uint256 tokenId = mint(_edition, address(this));

        vm.expectRevert("NOT_AUTHORIZED");
        vm.prank(unapproved);
        IERC721(_edition).transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    function test_transferFrom_approvedWorks(address approved) public {
        vm.assume(approved != address(0));

        uint256 tokenId = mint(_edition, address(this));
        IERC721(_edition).approve(approved, tokenId);

        // then bob can burn the token
        vm.prank(approved);
        IERC721(_edition).transferFrom(address(this), BURN_ADDRESS, tokenId);
        assertEq(IERC721(_edition).ownerOf(tokenId), BURN_ADDRESS);
    }

    function test_transferFrom_approvedFailsWithWrongTokenId(address approved) public {
        mint(_edition, 2);

        vm.assume(approved != address(0));
        vm.prank(IERC721(_edition).ownerOf(1));
        IERC721(_edition).approve(approved, 1);

        address token2Owner = IERC721(_edition).ownerOf(2);

        // address is approved for token 1
        vm.prank(approved);
        vm.expectRevert("NOT_AUTHORIZED");
        IERC721(_edition).transferFrom(token2Owner, BURN_ADDRESS, 2);
    }

    function test_transferFrom_approvedFailsWithUnmintedTokenId(address approved, uint256 wrongTokenId) public {
        uint256 tokenId = mint(_edition, address(this));

        vm.assume(approved != address(0));
        vm.assume(wrongTokenId != tokenId);
        vm.assume(wrongTokenId != 0);

        vm.expectRevert("NOT_AUTHORIZED");
        IERC721(_edition).approve(approved, wrongTokenId);
    }

    function test_transferFrom_approvedForAllWorks(address approved) public {
        uint256 tokenId = mint(_edition, address(this));
        IERC721(_edition).setApprovalForAll(approved, true);

        // then bob can burn the token
        vm.prank(approved);
        IERC721(_edition).transferFrom(address(this), BURN_ADDRESS, tokenId);
        assertEq(IERC721(_edition).ownerOf(tokenId), BURN_ADDRESS);
    }

    function test_transferFrom_twiceFails() public {
        uint256 tokenId = mint(_edition, address(this));

        IERC721(_edition).transferFrom(address(this), BURN_ADDRESS, tokenId);

        vm.expectRevert("WRONG_FROM");
        IERC721(_edition).transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                             ERC2981 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_supportsInterface() public {
        assertEq(EditionBase(_edition).supportsInterface(0x2a55205a), true); // ERC2981
        assertEq(EditionBase(_edition).supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(EditionBase(_edition).supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(EditionBase(_edition).supportsInterface(0x5b5e139f), true); // ERC721Metadata
    }

    function test_royaltyInfo_royaltyAmount(uint128 salePrice) public {
        // uint128 for salePrice is plenty big and avoids overflow errors
        (, uint256 fee) = EditionBase(_edition).royaltyInfo(1, salePrice);
        assertEq(fee, uint256(salePrice) * DEFAULT_CONFIG.royaltiesBps / 100_00);
    }

    function test_royaltyInfo_royaltyRecipientUpdatedAfterOwnershipTransferred(address newOwner) public {
        (address recipient,) = EditionBase(_edition).royaltyInfo(1, 1 ether);
        assertEq(recipient, editionOwner);

        // when we transfer ownership
        vm.prank(editionOwner);
        EditionBase(_edition).transferOwnership(newOwner);

        // then the royalty recipient is updated
        (recipient,) = EditionBase(_edition).royaltyInfo(1, 1 ether);
        assertEq(recipient, newOwner);
    }

    function test_royaltyInfo_editionWithNoRoyalties() public {
        EditionConfig memory config = DEFAULT_CONFIG.withRoyaltiesBps(0).withName("No Royalties");

        EditionBase editionNoRoyalties = EditionBase(create(config));

        (, uint256 royaltyAmount) = editionNoRoyalties.royaltyInfo(1, 100);
        assertEq(royaltyAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                           SUPPLY LIMIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mint_overSupplyLimitFails(uint256 n) public {
        n = bound(n, EditionBase(_edition).editionSize() + 1, 1000);
        mint(_edition, n, approvedMinter, abi.encodeWithSelector(SoldOut.selector));
    }

    /*//////////////////////////////////////////////////////////////
                            TIME LIMIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_isMintingEnded_withNoTimeLimit(uint256 warpTime) public {
        vm.warp(warpTime);
        assertEq(EditionBase(_edition).isMintingEnded(), false);
    }

    function test_mint_fromTimeLimitedEdition_duringMintingPeriod() public {
        // minting is allowed
        assertEq(EditionBase(_timeLimitedEdition).isMintingEnded(), false);
        mint(_timeLimitedEdition, address(this));
    }

    function test_mintSingle_fromTimeLimitedEdition_afterMintingPeriod() public {
        // after the mint period
        vm.warp(block.timestamp + 3 days);

        // isMintingEnded() returns true
        assertEq(EditionBase(_timeLimitedEdition).isMintingEnded(), true);

        // minting one fails
        mint(_timeLimitedEdition, address(this), approvedMinter, abi.encodeWithSelector(TimeLimitReached.selector));

        // minting multiple
        mint(_timeLimitedEdition, 42, approvedMinter, abi.encodeWithSelector(TimeLimitReached.selector));

        // it returns the expected totalSupply
        assertEq(EditionBase(_timeLimitedEdition).totalSupply(), 0);
    }
}
