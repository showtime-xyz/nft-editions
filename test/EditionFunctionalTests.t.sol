// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console2} from "forge-std/console2.sol";

import {IERC721ReceiverUpgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

import {Base64} from "contracts/utils/Base64.sol";
import {Edition} from "contracts/Edition.sol";
import {EditionCreator, IEdition} from "contracts/EditionCreator.sol";
import {LibString} from "contracts/utils/LibString.sol";

import "contracts/interfaces/Errors.sol";

function newIntegerOverflow(uint256 value) pure returns (bytes memory) {
    return abi.encodeWithSelector(IntegerOverflow.selector, value);
}

function newBadAttribute(string memory name, string memory value) pure returns (bytes memory) {
    return abi.encodeWithSelector(BadAttribute.selector, name, value);
}

/// @dev expects dataUri to be "data:application/json;base64,..."
function parseDataUri(string memory dataUri) pure returns (string memory json) {
    string memory base64Slice = LibString.slice(
        dataUri,
        29, // length of 'data:application/json;base64,'
        bytes(dataUri).length
    );

    json = string(Base64.decode(base64Slice));
}

function jsonString(string memory json, string memory key) pure returns (string memory) {
    return abi.decode(
        stdJson.parseRaw(json, key),
        (string)
    );
}

contract UnsuspectingContract {}

contract ERC721AwareContract is IERC721ReceiverUpgradeable {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract EditionFunctionalTests is Test {
    event PriceChanged(uint256 amount);
    event ExternalUrlUpdated(string oldExternalUrl, string newExternalUrl);
    event PropertyUpdated(string name, string oldValue, string newValue);
    event Initialized();
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    struct EditionParams {
        string name;
        string symbol;
        string description;
        string animationUrl;
        string imageUrl;
        uint256 editionSize;
        uint256 royaltiesBps;
        uint256 mintPeriod;
    }

    EditionParams internal DEFAULT_PARAMS = EditionParams(
        "Testing Token",
        "TEST",
        "This is a testing token for all",
        "",
        "ipfs://someImageHash",
        10,
        1000,
        0
    );

    EditionCreator editionCreator;
    Edition editionImpl;
    Edition edition;

    uint256 tokenId;

    address editionOwner;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    address constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    ERC721AwareContract erc721AwareContract = new ERC721AwareContract();
    UnsuspectingContract unsuspectingContract = new UnsuspectingContract();

    function createEdition(EditionParams memory params, bytes memory expectedError)
        internal
        returns (Edition _edition)
    {
        vm.startPrank(editionOwner);

        if (expectedError.length > 0) {
            vm.expectRevert(expectedError);
        }

        _edition = Edition(
            address(
                editionCreator.createEdition(
                    params.name,
                    params.symbol,
                    params.description,
                    params.animationUrl,
                    params.imageUrl,
                    params.editionSize,
                    params.royaltiesBps,
                    params.mintPeriod
                )
            )
        );

        // so that we can mint from this without having to call prank all the time
        // only perform this if we expect no error
        if (expectedError.length == 0) {
            _edition.setApprovedMinter(address(this), true);
        }

        vm.stopPrank();
        return _edition;
    }

    function createEdition(EditionParams memory params) internal returns (Edition) {
        return createEdition(params, "");
    }

    function createEdition() internal returns (Edition) {
        return createEdition(DEFAULT_PARAMS, "");
    }

    function setUp() public {
        editionOwner = makeAddr("editionOwner");
        editionImpl = new Edition();
        editionCreator = new EditionCreator(address(editionImpl));

        edition = createEdition();

        tokenId = edition.mint(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR / INITIALIZER TESTS
    //////////////////////////////////////////////////////////////*/

    function testConstructorEmitsInitializedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit Initialized();
        new Edition();
    }

    function testNoOwnerAfterConstructor() public {
        Edition newImpl = new Edition();
        assertEq(newImpl.owner(), address(0));
    }

    function testInitializerEmitsOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, true, true);
        emit OwnershipTransferred(address(0), address(this));
        editionCreator.createEdition(
            "name",
            "symbol",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0xcccccccccccccc, // editionSize
            0xaaaa, // royaltyBPS
            0xbbbbbbbbbbbbbb // mintPeriodSeconds
        );
    }

    function testDoesNotAllowReinitializationOfTheImplContract() public {
        Edition newImpl = new Edition();

        vm.expectRevert("ALREADY_INITIALIZED");
        newImpl.initialize(
            bob,
            "name",
            "symbol",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0xcccccccccccccc, // editionSize
            0xaaaa, // royaltyBPS
            0xbbbbbbbbbbbbbb // mintPeriodSeconds
        );
    }

    function testDoesNotAllowReinitializationOfProxyContracts() public {
        vm.expectRevert("ALREADY_INITIALIZED");
        edition.initialize(
            bob,
            "name",
            "symbol",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0xcccccccccccccc, // editionSize
            0xaaaa, // royaltyBPS
            0xbbbbbbbbbbbbbb // mintPeriodSeconds
        );
    }

    function testCreateDuplicate() public {
        createEdition(DEFAULT_PARAMS, "ERC1167: create2 failed");
    }

    function testEditionSizeOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        EditionParams memory params = DEFAULT_PARAMS;
        params.editionSize = tooBig;
        params.name = "Edition Size Too Big";

        createEdition(params, newIntegerOverflow(tooBig));
    }

    function testMintPeriodOverflow() public {
        uint256 tooBig = uint256(type(uint64).max) + 1;
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Mint Period Too Big";
        params.mintPeriod = tooBig;

        createEdition(params, newIntegerOverflow(tooBig + block.timestamp));
    }

    function testRoyaltiesOverflow() public {
        uint256 tooBig = uint256(type(uint16).max) + 1;
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Royalties Too Big";
        params.royaltiesBps = tooBig;

        createEdition(params, newIntegerOverflow(tooBig));
    }

    /*//////////////////////////////////////////////////////////////
                        STRING PROPERTIES TESTS
    //////////////////////////////////////////////////////////////*/

    function setProperty(string memory name, string memory value) internal {
        string[] memory properties = new string[](1);
        properties[0] = name;

        string[] memory values = new string[](1);
        values[0] = value;

        vm.prank(editionOwner);
        edition.setStringProperties(properties, values);
    }

    function setProperties(/* nothing */) internal {
        string[] memory properties = new string[](0);
        string[] memory values = new string[](0);
        vm.prank(editionOwner);
        edition.setStringProperties(properties, values);
    }

    function setProperties(
        string memory name1, string memory value1,
        string memory name2, string memory value2
    ) internal {
        string[] memory properties = new string[](2);
        properties[0] = name1;
        properties[1] = name2;

        string[] memory values = new string[](2);
        values[0] = value1;
        values[1] = value2;

        vm.prank(editionOwner);
        edition.setStringProperties(properties, values);
    }

    function testOnlyOwnerCanSetStringProperties() public {
        string[] memory properties = new string[](0);
        string[] memory values = new string[](0);

        vm.expectRevert("UNAUTHORIZED");
        edition.setStringProperties(properties, values);
    }

    function testRejectsEmptyPropertyNames() public {
        vm.expectRevert(newBadAttribute("", "value"));
        setProperty("", "value");
    }

    function testRejectsStringPropertiesWhereTheNamesAndValueDontMatch() public {
        string[] memory properties = new string[](1);
        properties[0] = "name1";

        string[] memory values = new string[](2);
        values[0] = "value1";
        values[1] = "value2";

        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        vm.prank(editionOwner);
        edition.setStringProperties(properties, values);
    }

    function testReflectsSinglePropertyInMetadata() public {
        setProperty("property_name", "property_value");
        string memory json = parseDataUri(edition.tokenURI(tokenId));
        string memory value = stdJson.readString(json, ".properties.property_name");

        assertEq(value, "property_value");
    }

    function testReflectsMultipleStringPropertiesInMetadata() public {
        setProperties(
            "property_name1", "property_value1",
            "property_name2", "property_value2"
        );

        string memory json = parseDataUri(edition.tokenURI(tokenId));
        assertEq(stdJson.readString(json, ".properties.property_name1"), "property_value1");
        assertEq(stdJson.readString(json, ".properties.property_name2"), "property_value2");
    }

    function testCanCreateUpdateDeleteSingleProperty() public {
        vm.expectEmit(true, true, true, true);
        emit PropertyUpdated("property_name", "", "initial_value");
        setProperty("property_name", "initial_value");

        vm.expectEmit(true, true, true, true);
        emit PropertyUpdated("property_name", "initial_value", "updated_value");
        setProperty("property_name", "updated_value");

        // delete does not emit an event
        setProperties();

        string memory json = parseDataUri(edition.tokenURI(tokenId));
        assertEq(stdJson.parseRaw(json, ".properties").length, 0);
    }

    function testCanCreateUpdateDeleteMultipleProperties() public {
        // setup: start with 2 properties
        setProperties(
            "property_name1", "property_value1",
            "property_name2", "property_value2"
        );

        // when we set properties again without property_name2
        setProperty("property_name1", "updated_value1");
        string memory json = parseDataUri(edition.tokenURI(tokenId));
        assertEq(stdJson.readString(json, ".properties.property_name1"), "updated_value1");

        // then property_name2 has been deleted
        vm.expectRevert();
        stdJson.readString(json, ".properties.property_name2");

        // when we set properties to an empty array
        setProperties();

        // then they are both removed
        json = parseDataUri(edition.tokenURI(tokenId));
        assertEq(stdJson.parseRaw(json, ".properties").length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                             METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function testMetadataWellFormed() public {
        assertEq(edition.name(), DEFAULT_PARAMS.name);
        assertEq(edition.symbol(), DEFAULT_PARAMS.symbol);
        assertEq(edition.description(), DEFAULT_PARAMS.description);
        assertEq(edition.animationUrl(), DEFAULT_PARAMS.animationUrl);
        assertEq(edition.imageUrl(), DEFAULT_PARAMS.imageUrl);
        assertEq(edition.editionSize(), DEFAULT_PARAMS.editionSize);
        assertEq(edition.owner(), editionOwner);

        uint256 salePrice = 1 ether;
        (address recipient, uint256 royalties) = edition.royaltyInfo(tokenId, salePrice);
        assertEq(royalties, (DEFAULT_PARAMS.royaltiesBps * salePrice / 100_00));
        assertEq(recipient, editionOwner);
    }

    /// @dev fields need to be sorted alphabetically (see docs of vm.parseJson())
    struct ContractURISchema {
        string description;
        address fee_recipient;
        string image;
        string name;
        uint256 seller_fee_basis_points;
    }

    /// @dev tests that the returned json object conforms exactly to the schema (no spurious fields)
    function testContractURIWellFormed() public {
        string memory json = parseDataUri(edition.contractURI());
        ContractURISchema memory parsed = abi.decode(vm.parseJson(json), (ContractURISchema));
        assertEq(parsed.name, DEFAULT_PARAMS.name);
        assertEq(parsed.description, DEFAULT_PARAMS.description);
        assertEq(parsed.image, DEFAULT_PARAMS.imageUrl);
        assertEq(parsed.seller_fee_basis_points, DEFAULT_PARAMS.royaltiesBps);
        assertEq(parsed.fee_recipient, editionOwner);
    }

    function testSetExternalURLAuth() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.setExternalUrl("https://example.com");
    }

    function testSetExternalURLEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ExternalUrlUpdated("", "https://example.com/externalUrl");
        vm.prank(editionOwner);
        edition.setExternalUrl("https://example.com/externalUrl");
    }

    function testExternalURLReflectedInGetter() public {
        vm.prank(editionOwner);
        edition.setExternalUrl("https://example.com/externalUrl");
        assertEq(edition.externalUrl(), "https://example.com/externalUrl");
    }

    function testExternalURLReflectedInContractURI() public {
        vm.prank(editionOwner);
        edition.setExternalUrl("https://example.com/externalUrl");

        string memory json = parseDataUri(edition.contractURI());
        assertEq(stdJson.readString(json, ".external_link"), "https://example.com/externalUrl");
    }

    function testExternalURLReflectedInTokenURI() public {
        vm.prank(editionOwner);
        edition.setExternalUrl("https://example.com/externalUrl");

        string memory json = parseDataUri(edition.tokenURI(tokenId));
        assertEq(stdJson.readString(json, ".external_url"), "https://example.com/externalUrl");
    }

    function testExternalURLCanBeUnset() public {
        // setup
        vm.prank(editionOwner);
        edition.setExternalUrl("https://example.com/externalUrl");

        // when we unset it, we expect an event
        vm.expectEmit(true, true, true, true);
        emit ExternalUrlUpdated("https://example.com/externalUrl", "");

        vm.prank(editionOwner);
        edition.setExternalUrl("");

        assertEq(edition.externalUrl(), "");
    }

    struct TokenURISchemaWithImage {
        string description;
        string image;
        string name;
        // empty properties object does not get deserialized (`"properties":{}`)
    }

    function testTokenUri() public {
        string memory json = parseDataUri(edition.tokenURI(tokenId));
        TokenURISchemaWithImage memory parsed = abi.decode(vm.parseJson(json), (TokenURISchemaWithImage));

        assertEq(parsed.name, string.concat(DEFAULT_PARAMS.name, " #1/10"));
        assertEq(parsed.description, DEFAULT_PARAMS.description);
        assertEq(parsed.image, DEFAULT_PARAMS.imageUrl);
    }

    /*//////////////////////////////////////////////////////////////
                             ERC2981 TESTS
    //////////////////////////////////////////////////////////////*/

    function testERC165Impl() public {
        assertEq(edition.supportsInterface(0x2a55205a), true); // ERC2981
        assertEq(edition.supportsInterface(0x01ffc9a7), true); // ERC165
        assertEq(edition.supportsInterface(0x80ac58cd), true); // ERC721
        assertEq(edition.supportsInterface(0x5b5e139f), true); // ERC721Metadata
    }

    function testRoyaltyRecipientUpdatedAfterOwnershipTransferred() public {
        (address recipient, ) = edition.royaltyInfo(1, 1 ether);
        assertEq(recipient, editionOwner);

        // when we transfer ownership
        vm.prank(editionOwner);
        edition.transferOwnership(bob);

        // then the royalty recipient is updated
        (recipient, ) = edition.royaltyInfo(1, 1 ether);
        assertEq(recipient, bob);
    }

    function testRoyaltyAmount(uint128 salePrice) public {
        // uint128 is plenty big and avoids overflow errors
        (, uint256 fee) = edition.royaltyInfo(1, salePrice);
        assertEq(fee, uint256(salePrice) * DEFAULT_PARAMS.royaltiesBps / 100_00);
    }

    function testEditionWithNoRoyalties() public {
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "No Royalties";
        params.royaltiesBps = 0;
        Edition editionNoRoyalties = createEdition(params);

        (, uint256 royaltyAmount) = editionNoRoyalties.royaltyInfo(1, 100);
        assertEq(royaltyAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT/BURN TESTS
    //////////////////////////////////////////////////////////////*/

    function testMintingUpdatesTotalSupply() public {
        assertEq(edition.totalSupply(), 1);
        edition.mint(bob);
        assertEq(edition.totalSupply(), 2);
        assertEq(edition.ownerOf(2), bob);
    }

    function testAllowsUserBurn() public {
        // no burn method, burning is done by transfering to the burn address
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);

        // as a result, totalSupply is unchanged
        assertEq(edition.totalSupply(), 1);

        // and the token is owned by the burn address
        assertEq(edition.ownerOf(tokenId), BURN_ADDRESS);
    }

    function testDoesNotAllowUnapprovedBurns() public {
        // bob has no approval for that token
        vm.prank(bob);
        vm.expectRevert("NOT_AUTHORIZED");
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    function testAllowsBurnIfApproved() public {
        // when we approve bob
        edition.approve(bob, tokenId);

        // then bob can burn the token
        vm.prank(bob);
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
        assertEq(edition.ownerOf(tokenId), BURN_ADDRESS);
    }

    function testAllowsBurnIfApprovedForAll() public {
        // when we approve bob
        edition.setApprovalForAll(bob, true);

        // then bob can burn the token
        vm.prank(bob);
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
        assertEq(edition.ownerOf(tokenId), BURN_ADDRESS);
    }

    function testDoesNotAllowBurningTwice() public {
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);

        vm.expectRevert("WRONG_FROM");
        edition.transferFrom(address(this), BURN_ADDRESS, tokenId);
    }

    function testMintBatch4() public {
        // make a batch of address with duplicates, unsorted
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        recipients[3] = alice;

        uint256 lastTokenId = edition.mintBatch(recipients);

        assertEq(lastTokenId, 5);
        assertEq(edition.totalSupply(), 5);
        assertEq(edition.ownerOf(2), alice);
        assertEq(edition.ownerOf(3), bob);
        assertEq(edition.ownerOf(4), charlie);
        assertEq(edition.ownerOf(5), alice);
        assertEq(edition.balanceOf(alice), 2);
    }

    function testMintEditionCanMintToUnsuspectingContracts() public {
        vm.expectEmit(true, true, false, false);
        emit Transfer(
            address(0),
            address(unsuspectingContract),
            /* whatever */
            0
        );

        edition.mint(address(unsuspectingContract));
    }

    function testSafeMintEditionCanNotMintToUnsuspectingContracts() public {
        // the "UNSAFE_RECIPIENT" error does not bubble up to the caller
        vm.expectRevert();
        edition.safeMint(address(unsuspectingContract));
    }

    function testSafeMintEditionCanMintToAwareContracts() public {
        vm.expectEmit(true, true, false, false);
        emit Transfer(
            address(0),
            address(erc721AwareContract),
            /* whatever */
            0
        );

        edition.mint(address(erc721AwareContract));
    }

    /*//////////////////////////////////////////////////////////////
                           SUPPLY LIMIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testCanNotMintMoreThanEditionSize() public {
        while (edition.totalSupply() < DEFAULT_PARAMS.editionSize) {
            edition.mint(bob);
        }

        vm.expectRevert(SoldOut.selector);
        edition.mint(bob);
    }

    function testCanNotMintBatchBiggerThanEditionSize() public {
        address[] memory recipients = new address[](DEFAULT_PARAMS.editionSize);
        for (uint256 i = 0; i < DEFAULT_PARAMS.editionSize; i++) {
            recipients[i] = bob;
        }

        vm.expectRevert(SoldOut.selector);
        edition.mintBatch(recipients);
    }

    /*//////////////////////////////////////////////////////////////
                            TIME LIMIT TESTS
    //////////////////////////////////////////////////////////////*/

    function testTimeLimitedEditionDuringMintingPeriod() public {
        // setup
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Time Limited Edition";
        params.mintPeriod = 2 days;
        Edition timeLimitedEdition = createEdition(params);

        // minting is allowed
        assertEq(timeLimitedEdition.isMintingEnded(), false);
        timeLimitedEdition.mint(bob);
    }

    function testTimeLimitedEditionAfterMintingPeriod() public {
        // setup
        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Time Limited Edition";
        params.mintPeriod = 2 days;
        Edition timeLimitedEdition = createEdition(params);

        vm.prank(editionOwner);
        timeLimitedEdition.setApprovedMinter(address(0), true); // allow anyone to mint

        // after the mint period
        vm.warp(block.timestamp + 3 days);

        // isMintingEnded() returns true
        assertEq(timeLimitedEdition.isMintingEnded(), true);

        // mint() fails
        vm.expectRevert(TimeLimitReached.selector);
        timeLimitedEdition.mint(bob);

        // mintBatch() fails
        address[] memory recipients = new address[](1);
        recipients[0] = bob;
        vm.expectRevert(TimeLimitReached.selector);
        timeLimitedEdition.mintBatch(recipients);

        // mint() with salePrice fails
        vm.prank(editionOwner);
        timeLimitedEdition.setSalePrice(1 ether);
        vm.deal(bob, 1 ether);

        vm.expectRevert(TimeLimitReached.selector);
        vm.prank(bob);
        timeLimitedEdition.mint{value: 1 ether}(bob);

        // it returns the expected totalSupply
        assertEq(timeLimitedEdition.totalSupply(), 0);
    }


    /*//////////////////////////////////////////////////////////////
                               AUTH TESTS
    //////////////////////////////////////////////////////////////*/

    function testOnlyOwnerCanSetApprovedMinter() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.setApprovedMinter(bob, true);
    }

    function testOnlyOwnerCanWithdraw() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.withdraw();
    }

    function testOnlyOwnerCanSetSalePrice() public {
        vm.expectRevert("UNAUTHORIZED");
        edition.setSalePrice(0 ether);
    }

    function testOnlyApprovedMinterCanMint() public {
        vm.expectRevert(Unauthorized.selector);
        vm.prank(bob);
        edition.mint(bob);
    }

    function testOnlyOwnerCanTransferOwnership() public {
        vm.expectRevert("UNAUTHORIZED");
        vm.prank(bob);
        edition.transferOwnership(bob);
    }


    /*//////////////////////////////////////////////////////////////
                            SALE PRICE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSetSalePriceSmallest() public {
        uint256 smallestPriceWei = 0.001 ether;
        vm.prank(editionOwner);
        edition.setSalePrice(smallestPriceWei);
        assertEq(edition.salePrice(), smallestPriceWei);
    }

    function testSetSalePriceLargest() public {
        uint256 largestPriceWei = 4294.967295 ether;
        vm.prank(editionOwner);
        edition.setSalePrice(largestPriceWei);
        assertEq(edition.salePrice(), largestPriceWei);
    }

    function testSetSalePriceUnderflow() public {
        uint256 tooSmall = 1 wei;
        vm.prank(editionOwner);
        vm.expectRevert(abi.encodeWithSignature("PriceTooLow()"));
        edition.setSalePrice(tooSmall);
    }

    function testSetSalePriceOverflow() public {
        uint256 tooBig = 4294.967296 ether;
        vm.prank(editionOwner);
        vm.expectRevert(newIntegerOverflow(0x100000000));
        edition.setSalePrice(tooBig);
    }

    function testSalePriceReflectedCorrectly() public {
        assertEq(edition.salePrice(), 0 ether);

        vm.prank(editionOwner);
        edition.setSalePrice(1 ether);

        assertEq(edition.salePrice(), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            PAID MINT TESTS
    //////////////////////////////////////////////////////////////*/

    function testFreeMintRefusesEth() public {
        // setup
        vm.prank(editionOwner);
        edition.setSalePrice(0);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        // bob can not mint with value
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mint{value: 1 ether}(bob);

        // bob can not safeMint with value
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.safeMint{value: 1 ether}(bob);

        // bob can not mintBatch with value
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        address[] memory recipients = new address[](1);
        recipients[0] = bob;
        edition.mintBatch{value: 1 ether}(recipients);
    }

    function testPaidMint() public {
        // setup
        uint256 price = 0.001 ether;

        vm.prank(editionOwner);
        edition.setSalePrice(price);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        // bob can not mint for free
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mint(bob);

        // when bob mints with the wrong price, it reverts
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mint{value: price + 1}(bob);

        // when bob mints with the correct price, it works
        vm.prank(bob);
        uint256 _tokenId = edition.mint{value: price}(bob);
        assertEq(edition.ownerOf(_tokenId), bob);
    }

    function testPaidSafeMint() public {
        // setup
        uint256 price = 0.001 ether;

        vm.prank(editionOwner);
        edition.setSalePrice(price);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        // bob can not mint for free
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.safeMint(bob);

        // when bob mints with the wrong price, it reverts
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.safeMint{value: price + 1}(bob);

        // when bob mints with the correct price, it works
        vm.prank(bob);
        uint256 _tokenId = edition.safeMint{value: price}(bob);
        assertEq(edition.ownerOf(_tokenId), bob);
    }

    function testPaidBatchMint() public {
        // setup
        uint256 price = 0.001 ether;

        vm.prank(editionOwner);
        edition.setSalePrice(price);

        vm.prank(editionOwner);
        edition.setApprovedMinter(address(0), true);

        vm.deal(bob, 1 ether);

        address[] memory recipients = new address[](3);
        recipients[0] = address(bob);
        recipients[1] = address(bob);
        recipients[2] = address(bob);

        // bob can not mint for free
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mintBatch(recipients);

        // when bob mints with the wrong price, it reverts
        vm.prank(bob);
        vm.expectRevert(WrongPrice.selector);
        edition.mintBatch{value: price}(recipients);

        // when bob mints with the correct price, it works
        vm.prank(bob);
        uint256 _tokenId = edition.mintBatch{value: 3 * price}(recipients);
        assertEq(edition.ownerOf(_tokenId), bob);
    }

    function testWithdraw(uint256 balance) public {
        // setup
        vm.deal(address(edition), balance);

        // when the owner withdraws
        vm.prank(editionOwner);
        edition.withdraw();

        // then the balance is transferred
        assertEq(address(edition).balance, 0);
        assertEq(address(editionOwner).balance, balance);
    }
}
