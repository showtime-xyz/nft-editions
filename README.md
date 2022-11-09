# Zora NFT Editions // Showtime Fork

[![CI](https://github.com/showtime-xyz/nft-editions/actions/workflows/ci.yml/badge.svg)](https://github.com/showtime-xyz/nft-editions/actions/workflows/ci.yml)

### Differences with the [original Zora Editions](https://github.com/ourzora/nft-editions)

TODO

### Where is the factory contract deployed:

TODO (not deployed yet)

### Getting started

```sh
# install hardhat
yarn add --dev hardhat

# build
npx hardhat compile

# test
npx hardhat test
forge test

# deploy dry run (replace with desired network)
source .env && forge script script/Deploy.s.sol --rpc-url mumbai

# deploy for real (replace with desired network)
source .env && forge script script/Deploy.s.sol --rpc-url mumbai --broadcast --verify

```
