// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Script, console2} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

import {EditionCreator} from "contracts/EditionCreator.sol";
import {Edition} from "contracts/Edition.sol";

contract CreateEdition is Script, Test {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        address owner = vm.addr(pk);
        console2.log("from address:", owner);
        vm.startBroadcast(pk);

        EditionCreator editionCreator = EditionCreator(
            0x1E504Cee4e586Ea462d1443956156F55535642aC
        );

        Edition edition = Edition(
            address(
                editionCreator.createEdition(
                    // quotes will need to be escaped:
                    unicode'"She gets visions" 👁️',
                    "SHOWTIME",
                    // newlines will need to be escaped
                    unicode"Playing in the background:\nKetto by Bonobo 🎶",
                    "",
                    "ipfs://QmSEBhh7A4JKjdRAVEwLGmfF5ckabAUnYVace9KjvyqMZj",
                    0, // open edition
                    2_50, // royaltyBPS
                    1 days // mintPeriodSeconds
                )
            )
        );

        edition.mint(owner);

        address[] memory recipients = new address[](7);
        recipients[0] = 0x03433830468d771A921314D75b9A1DeA53C165d7; // karmacoma.eth
        recipients[1] = 0x5969140066E0Efb3ee6e01710f319Bd8F19542C0; // alantoa.eth
        recipients[2] = 0xD3e9D60e4E4De615124D5239219F32946d10151D; // alexmasmej.eth
        recipients[3] = 0xAee2B2414f6ddd7E19697de40d828CBCDdAbf27F; // axeldelafosse.eth
        recipients[4] = 0xCcDd7eCA13716F442F01d14DBEDB6C427cb86dFA; // delvaze.eth
        recipients[5] = 0xF9984Db6A3bd7044f0d22c9008ddA296C0CC5468; // henryfontanier.eth
        recipients[6] = 0x3CFa5Fe88512Db62e40d0F91b7E59af34C1b098f; // nishanbende.eth

        edition.mintBatch(recipients);
        edition.setExternalUrl(
            "https://showtime.xyz/nft/polygon/0x1D6378e337f49dA12eEf49Bd1D8de3a1720115f4/0"
        );

        string[] memory names = new string[](1);
        names[0] = "Creator";
        string[] memory values = new string[](1);
        values[0] = "@AliceOnChain";
        edition.setStringProperties(names, values);

        vm.stopBroadcast();
    }
}
