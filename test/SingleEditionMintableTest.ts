import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  SingleEditionMintableCreator,
  SingleEditionMintable,
} from "../typechain";

function parseMetadataURI(uri: string): any {
  const parsedURI = parseDataURI(uri);
  if (!parsedURI) {
    throw "No parsed uri";
  }

  expect(parsedURI.mimeType.type).to.equal("application");
  expect(parsedURI.mimeType.subtype).to.equal("json");

  // Check metadata from edition
  const uriData = Buffer.from(parsedURI.body).toString("utf-8");
  const metadata = JSON.parse(uriData);
  return metadata;
}

describe("SingleEditionMintable", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: SingleEditionMintableCreator;
  let editionImpl: SingleEditionMintable;

  let createEdition = async function(factory: SingleEditionMintableCreator, args: any): Promise<SingleEditionMintable> {
    // first simulate the call to get the output
    // @ts-ignore
    const editionAddress = await factory.callStatic.createEdition(...args);

    // then actually call the function to create the edition
    // @ts-ignore
    await factory.createEdition(...args);

    const edition = (await ethers.getContractAt(
      "SingleEditionMintable",
      editionAddress
    )) as SingleEditionMintable;
    return edition;
  }

  beforeEach(async () => {
    const { SingleEditionMintableCreator, SingleEditionMintable } = await deployments.fixture([
      "SingleEditionMintableCreator",
      "SingleEditionMintable",
    ]);
    dynamicSketch = (await ethers.getContractAt(
      "SingleEditionMintableCreator",
      SingleEditionMintableCreator.address
    )) as SingleEditionMintableCreator;

    editionImpl = (await ethers.getContractAt(
      "SingleEditionMintable",
      SingleEditionMintable.address
    )) as SingleEditionMintable;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("does not allow re-initialization of the implementation contract", async () => {
    await expect(
      editionImpl.initialize(
        signerAddress,
        "test name",
        "SYM",
        "description",
        "animation",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "uri",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        12,
        12,
      )
    ).to.be.revertedWith("Initializable: contract is already initialized");
  });

  it("makes a new edition", async () => {
    const args = [
      "Testing Token",
      "TEST",
      "This is a testing token for all",
      "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "",
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      // 1% royalty since BPS
      10,
      10,
    ];

    const minterContract = await createEdition(dynamicSketch, args);
    expect(await minterContract.name()).to.be.equal("Testing Token");
    expect(await minterContract.symbol()).to.be.equal("TEST");
    const editionUris = await minterContract.getURIs();
    expect(editionUris[0]).to.be.equal("");
    expect(editionUris[1]).to.be.equal(
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    expect(editionUris[2]).to.be.equal(
      "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy"
    );
    expect(editionUris[3]).to.be.equal(
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    expect(await minterContract.editionSize()).to.be.equal(10);
    // TODO(iain): check bps
    expect(await minterContract.owner()).to.be.equal(signerAddress);
  });
  describe("with an edition", () => {
    let signer1: SignerWithAddress;
    let minterContract: SingleEditionMintable;

    beforeEach(async () => {
      signer1 = (await ethers.getSigners())[1];
      const args = [
        "Testing Token",
        "TEST",
        "This is a testing token for all",
        "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        10,
        10,
      ];

      minterContract = await createEdition(dynamicSketch, args);
    });

    it("has the expected contractURI", async () => {
      const contractURI = await minterContract.contractURI();
      const metadata = parseMetadataURI(contractURI);
      expect(metadata.name).to.equal("Testing Token");
      expect(metadata.description).to.equal("This is a testing token for all");
      // the edition only specified an animation url and no image url
      expect(metadata.image).to.be.undefined;
      expect(metadata.seller_fee_basis_points).to.equal(10);
      expect(metadata.fee_recipient).to.equal((await minterContract.owner()).toLowerCase());
    });

    it("can mint", async () => {
      // Mint first edition
      await expect(minterContract.mintEdition(signerAddress))
        .to.emit(minterContract, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          signerAddress,
          1
        );

      const tokenURI = await minterContract.tokenURI(1);
      const metadata = parseMetadataURI(tokenURI);
      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "Testing Token 1/10",
          description: "This is a testing token for all",
          animation_url:
            "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy?id=1",
          properties: { number: 1, name: "Testing Token" },
        })
      );
    });

    it("creates an unbounded edition", async () => {
      // no limit for edition size
      let args = [
        "Testing Unbounded Token",
        "TEST",
        "This is a testing token for all",
        "",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        0,
        0,
      ];

      minterContract = await createEdition(dynamicSketch, args);

      const contractURI = await minterContract.contractURI();
      const contractMetadata = parseMetadataURI(contractURI);
      expect(contractMetadata.name).to.equal("Testing Unbounded Token");
      expect(contractMetadata.description).to.equal("This is a testing token for all");
      expect(contractMetadata.image).to.equal("https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy");
      expect(contractMetadata.seller_fee_basis_points).to.equal(0);
      expect(contractMetadata.fee_recipient).to.equal((await minterContract.owner()).toLowerCase());

      expect(await minterContract.totalSupply()).to.equal(0);

      // Mint first edition
      await expect(minterContract.mintEdition(signerAddress))
        .to.emit(minterContract, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          signerAddress,
          1
        );

      expect(await minterContract.totalSupply()).to.be.equal(1);

      // Mint second edition
      await expect(minterContract.mintEdition(signerAddress))
        .to.emit(minterContract, "Transfer")
        .withArgs(
          "0x0000000000000000000000000000000000000000",
          signerAddress,
          2
        );

      expect(await minterContract.totalSupply()).to.be.equal(2);

      const tokenURI = await minterContract.tokenURI(1);
      const tokenURI2 = await minterContract.tokenURI(2);
      const metadata = parseMetadataURI(tokenURI);
      const metadata2 = parseMetadataURI(tokenURI2);

      expect(metadata2.name).to.be.equal("Testing Unbounded Token 2");

      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "Testing Unbounded Token 1",
          description: "This is a testing token for all",
          image:
            "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy?id=1",
          properties: { number: 1, name: "Testing Unbounded Token" },
        })
      );
    });

    it("creates an authenticated edition", async () => {
      await minterContract.mintEdition(await signer1.getAddress());
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.getAddress()
      );
    });
    it("allows user burn", async () => {
      await minterContract.mintEdition(await signer1.getAddress());
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.getAddress()
      );
      await minterContract.connect(signer1).burn(1);
      await expect(minterContract.ownerOf(1)).to.be.reverted;
    });

    it("does not allow re-initialization", async () => {
      await expect(
        minterContract.initialize(
          signerAddress,
          "test name",
          "SYM",
          "description",
          "animation",
          "0x0000000000000000000000000000000000000000000000000000000000000000",
          "uri",
          "0x0000000000000000000000000000000000000000000000000000000000000000",
          12,
          12,
        )
      ).to.be.revertedWith("Initializable: contract is already initialized");
      await minterContract.mintEdition(await signer1.getAddress());
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.getAddress()
      );
    });

    it("creates a set of editions", async () => {
      const [s1, s2, s3] = await ethers.getSigners();
      await minterContract.mintEditions([
        await s1.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
      ]);
      expect(await minterContract.ownerOf(1)).to.equal(await s1.getAddress());
      expect(await minterContract.ownerOf(2)).to.equal(await s2.getAddress());
      expect(await minterContract.ownerOf(3)).to.equal(await s3.getAddress());
      await minterContract.mintEditions([
        await s1.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
      ]);
      await expect(minterContract.mintEditions([signerAddress])).to.be.reverted;
      await expect(minterContract.mintEdition(signerAddress)).to.be.reverted;
    });
    it("returns interfaces correctly", async () => {
      // ERC2891 interface
      expect(await minterContract.supportsInterface("0x2a55205a")).to.be.true;
      // ERC165 interface
      expect(await minterContract.supportsInterface("0x01ffc9a7")).to.be.true;
      // ERC721 interface
      expect(await minterContract.supportsInterface("0x80ac58cd")).to.be.true;
    });
    describe("royalty 2981", () => {
      it("follows royalty payout for owner", async () => {
        await minterContract.mintEdition(signerAddress);
        // allows royalty payout info to be updated
        expect((await minterContract.royaltyInfo(1, 100))[0]).to.be.equal(
          signerAddress
        );
        await minterContract.transferOwnership(await signer1.getAddress());
        expect((await minterContract.royaltyInfo(1, 100))[0]).to.be.equal(
          await signer1.getAddress()
        );
      });

      it("sets the correct royalty amount", async () => {
        let args = [
          "Testing 2% Royalty Token",
          "TEST",
          "This is a testing token for all",
          "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
          "0x0000000000000000000000000000000000000000000000000000000000000000",
          "",
          "0x0000000000000000000000000000000000000000000000000000000000000000",
          // 2% royalty since BPS
          200,
          200,
        ];

        const minterContractNew = await createEdition(dynamicSketch, args);
        await minterContractNew.mintEdition(signerAddress);
        expect((await minterContractNew.royaltyInfo(1, ethers.utils.parseEther("1.0")))[1]).to.be.equal(
          ethers.utils.parseEther("0.02")
        );
      });
    });

    it("mints a large batch", async () => {
      // no limit for edition size
      let args = [
        "Testing Unlimited Token",
        "TEST",
        "This is a testing token for all",
        "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        0,
        0,
      ];

      minterContract = await createEdition(dynamicSketch, args);

      const [s1, s2, s3] = await ethers.getSigners();
      const [s1a, s2a, s3a] = [
        await s1.getAddress(),
        await s2.getAddress(),
        await s3.getAddress(),
      ];
      const toAddresses = [];
      for (let i = 0; i < 100; i++) {
        toAddresses.push(s1a);
        toAddresses.push(s2a);
        toAddresses.push(s3a);
      }
      await minterContract.mintEditions(toAddresses);
    });
    it("stops after editions are sold out", async () => {
      const [_, signer1] = await ethers.getSigners();

      expect(await minterContract.numberCanMint()).to.be.equal(10);

      // Mint first edition
      for (var i = 1; i <= 10; i++) {
        await expect(minterContract.mintEdition(await signer1.getAddress()))
          .to.emit(minterContract, "Transfer")
          .withArgs(
            "0x0000000000000000000000000000000000000000",
            await signer1.getAddress(),
            i
          );
      }

      expect(await minterContract.numberCanMint()).to.be.equal(0);

      await expect(
        minterContract.mintEdition(signerAddress)
      ).to.be.revertedWith("Sold out");

      const tokenURI = await minterContract.tokenURI(10);
      const metadata = parseMetadataURI(tokenURI);

      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "Testing Token 10/10",
          description: "This is a testing token for all",
          animation_url:
            "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy?id=10",
          properties: { number: 10, name: "Testing Token" },
        })
      );
    });
  });
});
