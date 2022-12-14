// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./fixtures/EditionFixture.sol";

contract EditionGasTests is EditionFixture {
    uint256 tokenId;
    Edition gasEdition;

    function setUp() public {
        __EditionFixture_setUp();

        EditionParams memory params = DEFAULT_PARAMS;
        params.name = "Gas Testing Edition";
        params.editionSize = 0;

        gasEdition = createEdition(params);
        tokenId = gasEdition.mint(address(this));
    }

    function testTokenURI() public view {
        gasEdition.tokenURI(tokenId);
    }

    function testContractURI() public view {
        gasEdition.contractURI();
    }

    function testMintSingle() public {
        gasEdition.mint(address(0xdEaD));
    }

    function testFailMintSingle() public {
        gasEdition.mint(address(0));
    }

    function testMintBatch1() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(0xdEaD);
        gasEdition.mintBatch(recipients);
    }

    function testMintBatch3() public {
        address[] memory recipients = new address[](3);
        recipients[0] = address(0xdEaD);
        recipients[1] = address(0xdEaD);
        recipients[2] = address(0xdEaD);
        gasEdition.mintBatch(recipients);
    }

    function testMintBatch10() public {
        address[] memory recipients = new address[](10);
        recipients[0] = address(0xdEaD);
        recipients[1] = address(0xdEaD);
        recipients[2] = address(0xdEaD);
        recipients[3] = address(0xdEaD);
        recipients[4] = address(0xdEaD);
        recipients[5] = address(0xdEaD);
        recipients[6] = address(0xdEaD);
        recipients[7] = address(0xdEaD);
        recipients[8] = address(0xdEaD);
        recipients[9] = address(0xdEaD);
        gasEdition.mintBatch(recipients);
    }
}
