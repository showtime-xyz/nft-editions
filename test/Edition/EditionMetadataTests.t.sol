// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {stdJson} from "forge-std/StdJson.sol";

import {Edition} from "contracts/Edition.sol";

import "./fixtures/EditionFixture.sol";

import {console2} from "forge-std/Test.sol";

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

contract EditionMetadataTests is EditionFixture {
    uint256 constant INTENSE_LENGTH = 100_000;

    Edition editionToEscape;
    Edition editionIntense;
    uint256 tokenId;

    function setUp() public {
        __EditionFixture_setUp();

        EditionParams memory intenseParams = DEFAULT_PARAMS;
        intenseParams.name = "This edition goes to 11";
        intenseParams.description = LibString.repeat("\\", INTENSE_LENGTH);
        editionIntense = createEdition(intenseParams);

        EditionParams memory escapeParams = DEFAULT_PARAMS;
        escapeParams.name = 'My "edition" is \t very special!\n';
        escapeParams.description = 'My "description" is also \t \\very\\ special!\r\n';
        editionToEscape = createEdition(escapeParams);

        tokenId = edition.mint(address(this));
        editionToEscape.mint(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
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

    /*//////////////////////////////////////////////////////////////
                          JSON ESCAPING TESTS
    //////////////////////////////////////////////////////////////*/

    function testLongEscapeDoubleQuotes() public {
        string memory input = LibString.repeat('"', INTENSE_LENGTH);
        string memory expected = LibString.repeat('\\"', INTENSE_LENGTH);
        string memory actual = LibString.escapeJSON(input);
        assertEq(actual, expected);
    }

    function testLongEscapeControlChar() public {
        string memory input = LibString.repeat(
            string(abi.encodePacked(bytes1(0))),
            INTENSE_LENGTH
        );
        string memory expected = LibString.repeat("\\u0000", INTENSE_LENGTH);
        string memory actual = LibString.escapeJSON(input);
        assertEq(actual, expected);
    }

    function testNameEscapedInContractURI() public {
        string memory json = parseDataUri(editionToEscape.contractURI());
        string memory rawName = abi.decode(stdJson.parseRaw(json, ".name"), (string));
        assertEq(rawName, 'My "edition" is \t very special!\n');

        string memory name = stdJson.readString(json, ".name");
        assertEq(name, 'My "edition" is \t very special!\n');
    }

    function testNameEscapedInTokenURI() public {
        string memory json = parseDataUri(editionToEscape.tokenURI(tokenId));
        string memory name = stdJson.readString(json, ".name");

        assertEq(name, 'My "edition" is \t very special!\n #1/10');
    }

    function testDescriptionEscapedInContractURI() public {
        string memory json = parseDataUri(editionToEscape.contractURI());
        string memory description = stdJson.readString(json, ".description");

        assertEq(description, 'My "description" is also \t \\very\\ special!\r\n');
    }

    function testDescriptionEscapedInTokenURI() public {
        setProperty("property_name", 'property\t"value"');
        string memory json = parseDataUri(edition.tokenURI(tokenId));
        string memory value = stdJson.readString(json, ".properties.property_name");

        assertEq(value, 'property\t"value"');
    }

    function testStringPropertiesEscaped() public {

    }

    function testEncodeContractURIIntenseDescription() public {
        string memory json = parseDataUri(editionIntense.contractURI());
        string memory description = stdJson.readString(json, ".description");

        assertEq(description, LibString.repeat("\\", INTENSE_LENGTH));
    }

    /*//////////////////////////////////////////////////////////////
                        STRING PROPERTIES TESTS
    //////////////////////////////////////////////////////////////*/

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

        // FIXME: uncomment when https://github.com/foundry-rs/foundry/issues/4630 is fixed
        // vm.expectRevert();
        // stdJson.readString(json, ".properties.property_name2");

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

    function testTokenUri() public {
        string memory json = parseDataUri(edition.tokenURI(tokenId));
        TokenURISchemaWithImage memory parsed = abi.decode(vm.parseJson(json), (TokenURISchemaWithImage));

        assertEq(parsed.name, string.concat(DEFAULT_PARAMS.name, " #1/10"));
        assertEq(parsed.description, DEFAULT_PARAMS.description);
        assertEq(parsed.image, DEFAULT_PARAMS.imageUrl);
    }
}
