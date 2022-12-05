⚠️ **Very experimental** contracts provided on an "as is" and "as available" basis.

```
contracts/solmate-initializable
├── auth
│   └── OwnedInitializable.sol — "A fork of solmate's Owned with an initializer instead of a constructor"
├── tokens
│   ├── ERC721I.sol — "An initializable ERC721"
│   ├── ERC721TokenReceiver.sol — "A generic interface for contracts that accept ERC721 tokens"
│   ├── PackedERC721Initializable.sol — "Deprecated"
│   ├── SS2ERC721.sol — "An SSTORE2-backed implementation of ERC721 optimized for minting in a single batch"
│   └── SS2ERC721I.sol — "An initializable SS2ERC721"
└── utils
    └── Initializable.sol — "A minimalist implementation of the Initializable pattern (incompatible with OpenZeppelin's)"
```
