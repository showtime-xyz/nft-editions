# ✦ Showtime // Zora NFT Editions

[![CI](https://github.com/showtime-xyz/nft-editions/actions/workflows/ci.yml/badge.svg)](https://github.com/showtime-xyz/nft-editions/actions/workflows/ci.yml)

We kept the same swiss-army knife approach to editions that we used and loved from the [original Zora Editions](https://github.com/ourzora/nft-editions):

- the base implementation is extremely versatile and composable
- new editions are minimal proxies (i.e. cheaper to deploy than a brand new ERC721)
- creator-owned collections with a unique address and on-chain royalties
- each token is numbered with on-chain metadata rendering
- support for ETH sales
- support for minting through contracts (e.g. to support ERC20 primary sales)

... and then we added our on spin on it

## Differences with the [original Zora Editions](https://github.com/ourzora/nft-editions)

### ✨ Features

- support for time-limited editions
- support for `contractURI()`, which means a nicer out-of-the-box experience on OpenSea. The collection will be automatically configured with the artwork as the collection cover, and the EIP-2981 creator fees will also be reflected (through `seller_fee_basis_points` and `fee_recipient`)
- support for `setExternalUrl(string)`, reflected in `contractURI()` and `tokenURI(uint256)`
- support for `setStringProperties(string[] names, string[] values)`, reflected in `tokenURI(uint256)`
- special characters in the `name` and `description` fields are escaped so that the JSON doesn't break in the contract and token URIs
- an edition can be deployed at the same address on multiple chains (instead of being an auto-incrementing counter, the edition id is now a hash of `<creator-addr|edition-name|animation-url|image-url>`)
- many gas efficiency improvements, particularly in the minting flow

### 🧰 Dev

- moved from hardhat to foundry
- solc upgraded from 0.8.6 to 0.8.16
- moved from OpenZeppelin's ERC721 as a base class to solmate's
- moved from OpenZeppelin's string libraries to Solady's (`LibString.toString(uint256)`, `LibString.escapeJSON(string)` and `Base64.encode(bytes)`)
- `Edition` now inherits from `EditionMetadataRenderer` instead of using an external `SharedNFTLogic` library
- Solidity errors instead of strings
- [removed unnecessary functions from the ABI](https://github.com/showtime-xyz/nft-editions/commit/9464226141b4e4efe883ca23716c5a3c302eaf12)

## Gas Comparison

See [editions-gas-bench](https://github.com/karmacoma-eth/editions-gas-bench) for the full methodology.

### Creating a new edition

|                         | Zora editions | Showtime editions | % change |
| ----------------------- | ------------- | ----------------- | -------- |
| testCreateNewEdition()  | 341563        | 225259            | \-34.05% |

### Single Mint

|                         | Zora editions | Showtime editions | % change |
| ----------------------- | ------------- | ----------------- | -------- |
| testMintByContract()    | 57883         | 50702             | \-12.41% |
| testMintByOwner()       | 48457         | 49869             | 2.91%    |
| testMintOpenEdition()   | 67489         | 64612             | \-4.26%  |

💁‍♂️ we purposefully optimised for the mint-by-contract flow because this is the most common by far for us (i.e. a contract is an approved minter, e.g. to enforce some requirements such as an allowlist). We made the trade-off to deprioritize mints that come from the owner because it should be much less likely in practice.

### Batch Mint

|                         | Zora editions | Showtime editions | % change |
| ----------------------- | ------------- | ----------------- | -------- |
| testMint10ByContract()  | 525498        | 515257            | \-1.95%  |
| testMint10ByOwner()     | 512988        | 511354            | \-0.32%  |
| testMint10OpenEdition() | 515336        | 509392            | \-1.15%  |

### View Functions

|                         | Zora editions | Showtime editions | % change |
| ----------------------- | ------------- | ----------------- | -------- |
| testContractURI()       | n/a           | 42595             |          |
| testTokenURI()          | 55674         | 42986             | \-22.79% |

✨ credit to [Solady's](https://github.com/Vectorized/solady/) Base64.sol and LibString.sol for this improvement

### Other

|                         | Zora editions | Showtime editions | % change |
| ----------------------- | ------------- | ----------------- | -------- |
| testTransferFrom()      | 43090         | 40465             | \-6.09%  |

✨ credit to [solmate](https://github.com/transmissions11/solmate/)'s ERC721.sol for this improvement



## 🏭 Where is the `EditionCreator` factory contract deployed?

TODO (not deployed yet)

## 👶 How do I deploy a new edition?

Call `EditionCreator.createEdition(...)`:

```solidity
/// Creates a new edition contract as a factory with a deterministic address
/// Important: most of these fields can not be changed after calling
/// @param _name Name of the edition
/// @param _symbol Symbol of the edition
/// @param _description Description of the edition
/// @param _animationUrl Link to video for each token in this edition, ideally "ipfs://..."
/// @param _imageUrl Link to an image for each token in this edition, ideally "ipfs://..."
/// @param _editionSize Set to a number greater than 0 for a limited edition, 0 for an open edition
/// @param _royaltyBPS Royalty amount in basis points (1/100th of a percent) to be paid to the owner of the edition
/// @param _mintPeriodSeconds Set to a number greater than 0 for a time-limited edition, 0 for no time limit. The mint period starts when the edition is created.
/// @return newContract The address of the created edition

function createEdition(...) external override returns (IEdition newContract)
```

This will:

- deploy an [EIP 1167](https://eips.ethereum.org/EIPS/eip-1167) minimal proxy to the reference `Edition` implementation
- transfer ownership of the edition to the `msg.sender`
- emit a `CreatedEdition(uint256 editionId, address creator, uint256 editionSize, address newEdition)` event


## 💁‍♂️ How do I create different kinds of editions?

- **limited edition**: create it with `_editionSize > 0`
- **time limited open edition**: create it with `_mintPeriodSeconds > 0` and `_editionSize == 0` (after this duration, nobody will be able to mint)
- **a free mint for some accounts followed by a paid public mint**: you will probably want to call `setApprovedMinter(allowListContractAddress, true)` to authorize mints through a contract that implements an allowlist, and then call `setSalePrice(uint256)` and `setApprovedMinter(0, true)` to kick off the paid public mint


## 🧰 Getting started

```sh
# install foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# build
forge build

# test
forge test -vvv

# deploy dry run (replace with desired network)
source .env && forge script script/Deploy.s.sol --rpc-url mumbai

# deploy for real (replace with desired network)
source .env && forge script script/Deploy.s.sol --rpc-url mumbai --broadcast --verify

```
