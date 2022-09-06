# Zora NFT Editions // Showtime Fork

###

### What are these contracts?
1. `SingleEditionMintable`
   Each edition is a unique contract.
   This allows for easy royalty collection, clear ownership of the collection, and your own contract 🎉
2. `SingleEditionMintableCreator`
   Gas-optimized factory contract allowing you to easily + for a low gas transaction create your own edition mintable contract.
3. `SharedNFTLogic`
   Contract that includes dynamic metadata generation for your editions removing the need for a centralized server.
   imageUrl and animationUrl can be base64-encoded data-uris for these contracts totally removing the need for IPFS

### How do I create a new contract?

### Directly on the blockchain:
1. Find/Deploy the `SingleEditionMintableCreator` contract
2. Call `createEdition` on the `SingleEditionMintableCreator`

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

# deploy (replace with desired network)
hardhat deploy --network mumbai

# verify
hardhat sourcify --network rinkeby && hardhat etherscan-verify --network rinkeby
```
