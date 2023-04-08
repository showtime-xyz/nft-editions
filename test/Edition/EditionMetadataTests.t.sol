// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {stdJson} from "forge-std/StdJson.sol";

import {LibString} from "contracts/utils/LibString.sol";
import {Base64} from "contracts/utils/Base64.sol";
import {IOwned} from "contracts/solmate-initializable/auth/IOwned.sol";

import "./fixtures/EditionFixture.sol";


/// @dev fields need to be sorted alphabetically (see docs of vm.parseJson())
struct ContractURISchema {
    string description;
    address fee_recipient;
    string image;
    string name;
    uint256 seller_fee_basis_points;
}

struct TokenURISchemaWithImage {
    string description;
    string image;
    string name;
    // empty properties object does not get deserialized (`"properties":{}`)
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

abstract contract EditionMetadataTests is EditionFixture {
    using EditionConfigWither for EditionConfig;

    uint256 constant INTENSE_LENGTH = 100_000;

    EditionConfig INTENSE_CONFIG = DEFAULT_CONFIG
        .withName("This edition goes to 11")
        .withDescription(LibString.repeat("\\", INTENSE_LENGTH));

    EditionConfig ESCAPE_CONFIG = DEFAULT_CONFIG
        .withName('My "edition" is \t very special!\n')
        .withDescription('My "description" is also \t \\very\\ special!\r\n');

    EditionConfig REGULAR_CONFIG = DEFAULT_CONFIG
        .withName("Regular edition")
        .withDescription("Nothing special here");


    EditionBase internal __metadata_editionToEscape;
    EditionBase internal __metadata_editionIntense;
    EditionBase internal __metadata_edition;


    // implementation must initialize the __metadata_* edition contracts
    // and mint 1 token from each of them
    function __EditionMetadataTests_init() internal virtual;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function setProperty(string memory name, string memory value) internal {
        string[] memory properties = new string[](1);
        properties[0] = name;

        string[] memory values = new string[](1);
        values[0] = value;

        vm.prank(editionOwner);
        __metadata_edition.setStringProperties(properties, values);
    }

    function setProperties(/* nothing */) internal {
        string[] memory properties = new string[](0);
        string[] memory values = new string[](0);
        vm.prank(editionOwner);
        __metadata_edition.setStringProperties(properties, values);
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
        __metadata_edition.setStringProperties(properties, values);
    }

    /*//////////////////////////////////////////////////////////////
                          JSON ESCAPING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_escapeJSON_longEscapeDoubleQuotes() public {
        string memory input = LibString.repeat('"', INTENSE_LENGTH);
        string memory expected = LibString.repeat('\\"', INTENSE_LENGTH);
        string memory actual = LibString.escapeJSON(input);
        assertEq(actual, expected);
    }

    function test_escapeJSON_longEscapeControlChar() public {
        string memory input = LibString.repeat(
            string(abi.encodePacked(bytes1(0))),
            INTENSE_LENGTH
        );
        string memory expected = LibString.repeat("\\u0000", INTENSE_LENGTH);
        string memory actual = LibString.escapeJSON(input);
        assertEq(actual, expected);
    }

    function test_contractURI_nameEscaped() public {
        string memory json = parseDataUri(__metadata_editionToEscape.contractURI());
        string memory rawName = abi.decode(stdJson.parseRaw(json, ".name"), (string));
        assertEq(rawName, 'My "edition" is \t very special!\n');

        string memory name = stdJson.readString(json, ".name");
        assertEq(name, 'My "edition" is \t very special!\n');
    }

    function test_tokenURI_nameEscaped() public {
        string memory json = parseDataUri(IERC721Metadata(address(__metadata_editionToEscape)).tokenURI(1));
        string memory name = stdJson.readString(json, ".name");

        assertEq(name, 'My "edition" is \t very special!\n #1/10');
    }

    function test_contractURI_descriptionEscaped() public {
        string memory json = parseDataUri(__metadata_editionToEscape.contractURI());
        string memory description = stdJson.readString(json, ".description");

        assertEq(description, 'My "description" is also \t \\very\\ special!\r\n');
    }

    function test_tokenURI_descriptionEscaped() public {
        string memory json = parseDataUri(IERC721Metadata(address(__metadata_editionToEscape)).tokenURI(1));
        string memory description = stdJson.readString(json, ".description");

        assertEq(description, 'My "description" is also \t \\very\\ special!\r\n');
    }

    function test_tokenURI_propertiesEscaped() public {
        setProperty("property_name", 'property\t"value"');
        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        string memory value = stdJson.readString(json, ".properties.property_name");

        assertEq(value, 'property\t"value"');
    }

    function test_contractURI_intenseDescriptionEscaped() public {
        string memory json = parseDataUri(__metadata_editionIntense.contractURI());
        string memory description = stdJson.readString(json, ".description");

        assertEq(description, LibString.repeat("\\", INTENSE_LENGTH));
    }

    /*//////////////////////////////////////////////////////////////
                        STRING PROPERTIES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setProperties_onlyOwner() public {
        string[] memory properties = new string[](0);
        string[] memory values = new string[](0);

        vm.expectRevert("UNAUTHORIZED");
        __metadata_edition.setStringProperties(properties, values);
    }

    function test_setProperties_rejectsEmptyPropertyNames() public {
        vm.expectRevert(newBadAttribute("", "value"));
        setProperty("", "value");
    }

    function test_setProperties_rejectsLengthMismatch() public {
        string[] memory properties = new string[](1);
        properties[0] = "name1";

        string[] memory values = new string[](2);
        values[0] = "value1";
        values[1] = "value2";

        vm.expectRevert(abi.encodeWithSelector(LengthMismatch.selector));
        vm.prank(editionOwner);
        __metadata_edition.setStringProperties(properties, values);
    }

    function test_setProperties_reflectsSinglePropertyInMetadata() public {
        setProperty("property_name", "property_value");
        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        string memory value = stdJson.readString(json, ".properties.property_name");

        assertEq(value, "property_value");
    }

    function test_setProperties_notReflectedInContractURI() public {
        setProperty("property_name", "property_value");
        string memory json = parseDataUri(EditionBase(address(__metadata_edition)).contractURI());
        string memory value = stdJson.readString(json, ".properties.property_name");

        assertEq(value, "");
    }

    function testReflectsMultipleStringPropertiesInMetadata() public {
        setProperties(
            "property_name1", "property_value1",
            "property_name2", "property_value2"
        );

        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        assertEq(stdJson.readString(json, ".properties.property_name1"), "property_value1");
        assertEq(stdJson.readString(json, ".properties.property_name2"), "property_value2");
    }

    function test_setProperties_canCreateUpdateDeleteSingleProperty() public {
        vm.expectEmit(true, true, true, true);
        emit PropertyUpdated("property_name", "", "initial_value");
        setProperty("property_name", "initial_value");

        vm.expectEmit(true, true, true, true);
        emit PropertyUpdated("property_name", "initial_value", "updated_value");
        setProperty("property_name", "updated_value");

        // delete does not emit an event
        setProperties();

        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        assertEq(stdJson.parseRaw(json, ".properties").length, 0);
    }

    function test_setProperties_canCreateUpdateDeleteMultipleProperties() public {
        // setup: start with 2 properties
        setProperties(
            "property_name1", "property_value1",
            "property_name2", "property_value2"
        );

        // when we set properties again without property_name2
        setProperty("property_name1", "updated_value1");
        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        assertEq(stdJson.readString(json, ".properties.property_name1"), "updated_value1");

        // then property_name2 has been deleted

        // FIXME: uncomment when https://github.com/foundry-rs/foundry/issues/4630 is fixed
        // vm.expectRevert();
        // stdJson.readString(json, ".properties.property_name2");

        // when we set properties to an empty array
        setProperties();

        // then they are both removed
        json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        assertEq(stdJson.parseRaw(json, ".properties").length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                             METADATA TESTS
    //////////////////////////////////////////////////////////////*/

    function test_metadata_wellFormed() public {
        assertEq(IERC721Metadata(address(__metadata_edition)).name(), REGULAR_CONFIG.name);
        assertEq(IERC721Metadata(address(__metadata_edition)).symbol(), REGULAR_CONFIG.symbol);
        assertEq(__metadata_edition.description(), REGULAR_CONFIG.description);
        assertEq(__metadata_edition.animationUrl(), REGULAR_CONFIG.animationUrl);
        assertEq(__metadata_edition.imageUrl(), REGULAR_CONFIG.imageUrl);
        assertEq(__metadata_edition.editionSize(), REGULAR_CONFIG.editionSize);
        assertEq(IOwned(address(__metadata_edition)).owner(), editionOwner);

        uint256 salePrice = 1 ether;
        (address recipient, uint256 royalties) = __metadata_edition.royaltyInfo(1, salePrice);
        assertEq(royalties, (REGULAR_CONFIG.royaltiesBps * salePrice / 100_00));
        assertEq(recipient, editionOwner);
    }

    /// @dev tests that the returned json object conforms exactly to the schema (no spurious fields)
    function test_contractURI_wellFormed() public {
        string memory json = parseDataUri(__metadata_edition.contractURI());
        ContractURISchema memory parsed = abi.decode(vm.parseJson(json), (ContractURISchema));
        assertEq(parsed.name, REGULAR_CONFIG.name);
        assertEq(parsed.description, REGULAR_CONFIG.description);
        assertEq(parsed.image, REGULAR_CONFIG.imageUrl);
        assertEq(parsed.seller_fee_basis_points, REGULAR_CONFIG.royaltiesBps);
        assertEq(parsed.fee_recipient, editionOwner);
    }

    function test_setExternalUrl_onlyOwner() public {
        vm.expectRevert("UNAUTHORIZED");
        __metadata_edition.setExternalUrl("https://example.com");
    }

    function test_setExternalUrl_emitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ExternalUrlUpdated("", "https://example.com/externalUrl");
        vm.prank(editionOwner);
        __metadata_edition.setExternalUrl("https://example.com/externalUrl");
    }

    function test_setExternalUrl_reflectedInGetter() public {
        vm.prank(editionOwner);
        __metadata_edition.setExternalUrl("https://example.com/externalUrl");
        assertEq(__metadata_edition.externalUrl(), "https://example.com/externalUrl");
    }

    function test_setExternalUrl_reflectedInContractURI() public {
        vm.prank(editionOwner);
        __metadata_edition.setExternalUrl("https://example.com/externalUrl");

        string memory json = parseDataUri(__metadata_edition.contractURI());
        assertEq(stdJson.readString(json, ".external_link"), "https://example.com/externalUrl");
    }

    function test_setExternalUrl_reflectedInTokenURI() public {
        vm.prank(editionOwner);
        __metadata_edition.setExternalUrl("https://example.com/externalUrl");

        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        assertEq(stdJson.readString(json, ".external_url"), "https://example.com/externalUrl");
    }

    function test_setExternalUrl_canUnset() public {
        // setup
        vm.prank(editionOwner);
        __metadata_edition.setExternalUrl("https://example.com/externalUrl");

        // when we unset it, we expect an event
        vm.expectEmit(true, true, true, true);
        emit ExternalUrlUpdated("https://example.com/externalUrl", "");

        vm.prank(editionOwner);
        __metadata_edition.setExternalUrl("");

        assertEq(__metadata_edition.externalUrl(), "");
    }

    function test_tokenURI_fail(uint256 tokenId) public {
        vm.assume(tokenId != 1);

        vm.expectRevert("NOT_MINTED");
        IERC721Metadata(address(__metadata_edition)).tokenURI(tokenId);
    }

    function test_tokenURI_pass() public {
        string memory json = parseDataUri(IERC721Metadata(address(__metadata_edition)).tokenURI(1));
        TokenURISchemaWithImage memory parsed = abi.decode(vm.parseJson(json), (TokenURISchemaWithImage));

        assertEq(parsed.name, string.concat(REGULAR_CONFIG.name, " #1/10"));
        assertEq(parsed.description, REGULAR_CONFIG.description);
        assertEq(parsed.image, REGULAR_CONFIG.imageUrl);
    }
}
