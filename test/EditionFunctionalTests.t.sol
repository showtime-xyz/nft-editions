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

function jsonString(string memory json, string memory key) returns (string memory) {
    return abi.decode(
        stdJson.parseRaw(json, key),
        (string)
    );
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

    string constant DEFAULT_NAME = "Testing Token";
    string constant DEFAULT_SYMBOL = "TEST";
    string constant DEFAULT_DESCRIPTION = "This is a testing token for all";
    string constant DEFAULT_ANIMATION_URL = "";
    string constant DEFAULT_IMAGE_URL = "ipfs://someImageHash";
    uint256 constant DEFAULT_EDITION_SIZE = 10;
    uint256 constant DEFAULT_ROYALTIES_BPS = 1000;
    uint256 constant DEFAULT_MINT_PERIOD = 0;

    EditionCreator editionCreator;
    Edition editionImpl;
    Edition edition;

    uint256 tokenId;

    address editionOwner;
    address bob = makeAddr("bob");

    function createEdition(string memory name, string memory description)
        internal
        returns (Edition _edition)
    {
        vm.startPrank(editionOwner);
        _edition = Edition(
            address(
                editionCreator.createEdition(
                    name,
                    DEFAULT_SYMBOL,
                    description,
                    DEFAULT_ANIMATION_URL,
                    DEFAULT_IMAGE_URL,
                    DEFAULT_EDITION_SIZE,
                    DEFAULT_ROYALTIES_BPS,
                    DEFAULT_MINT_PERIOD
                )
            )
        );

        // so that we can mint from this without having to call prank all the time
        _edition.setApprovedMinter(address(this), true);
        vm.stopPrank();

        return _edition;
    }

    function setUp() public {
        editionOwner = makeAddr("editionOwner");
        editionImpl = new Edition();
        editionCreator = new EditionCreator(address(editionImpl));

        edition = createEdition(
            DEFAULT_NAME,
            DEFAULT_DESCRIPTION
        );

        tokenId = edition.mint(address(0xdEaD));
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
        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );

        vm.expectRevert("ERC1167: create2 failed");
        editionCreator.createEdition(
            "name",
            "TEST",
            "description",
            "https://example.com/animation.mp4",
            "https://example.com/image.png",
            0, // editionSize
            0, // royaltyBPS
            0 // mintPeriodSeconds
        );
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
        assertEq(edition.name(), DEFAULT_NAME);
        assertEq(edition.symbol(), DEFAULT_SYMBOL);
        assertEq(edition.description(), DEFAULT_DESCRIPTION);
        assertEq(edition.animationUrl(), DEFAULT_ANIMATION_URL);
        assertEq(edition.imageUrl(), DEFAULT_IMAGE_URL);
        assertEq(edition.editionSize(), DEFAULT_EDITION_SIZE);
        assertEq(edition.owner(), editionOwner);

        uint256 salePrice = 1 ether;
        (address recipient, uint256 royalties) = edition.royaltyInfo(tokenId, salePrice);
        assertEq(royalties, (DEFAULT_ROYALTIES_BPS * salePrice / 100_00));
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
        assertEq(parsed.name, DEFAULT_NAME);
        assertEq(parsed.description, DEFAULT_DESCRIPTION);
        assertEq(parsed.image, DEFAULT_IMAGE_URL);
        assertEq(parsed.seller_fee_basis_points, DEFAULT_ROYALTIES_BPS);
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
        console2.log(json);

        TokenURISchemaWithImage memory parsed = abi.decode(vm.parseJson(json), (TokenURISchemaWithImage));

        assertEq(parsed.name, string.concat(DEFAULT_NAME, " #1/10"));
        assertEq(parsed.description, DEFAULT_DESCRIPTION);
        assertEq(parsed.image, DEFAULT_IMAGE_URL);
    }
}
