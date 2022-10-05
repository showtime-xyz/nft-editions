import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  EditionCreator,
  Edition,
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

describe("Edition", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: EditionCreator;
  let editionImpl: Edition;

  const DEFAULT_NAME = "Testing Token";
  const DEFAULT_SYMBOL = "TEST";
  const DEFAULT_DESCRIPTION = "This is a testing token for all";
  const DEFAULT_ANIMATION_URL = "";
  const DEFAULT_IMAGE_URL = "ipfs://someImageHash";
  const DEFAULT_MAX_SUPPLY = 10;
  const DEFAULT_ROYALTIES_BPS = 1000;
  const DEFAULT_METADATA_GRACE_PERIOD = 24 * 3600;

  const DEFAULT_ARGS = [
    DEFAULT_NAME,
    DEFAULT_SYMBOL,
    DEFAULT_DESCRIPTION,
    DEFAULT_ANIMATION_URL,
    DEFAULT_IMAGE_URL,
    DEFAULT_MAX_SUPPLY,
    DEFAULT_ROYALTIES_BPS,
    DEFAULT_METADATA_GRACE_PERIOD,
  ];

  let createEdition = async function (factory: EditionCreator, args: any): Promise<Edition> {
    // first simulate the call to get the output
    // @ts-ignore
    const editionAddress = await factory.callStatic.createEdition(...args);

    // then actually call the function to create the edition
    // @ts-ignore
    await factory.createEdition(...args);

    const edition = (await ethers.getContractAt(
      "Edition",
      editionAddress
    )) as Edition;
    return edition;
  }

  beforeEach(async () => {
    const { EditionCreator, Edition } = await deployments.fixture([
      "EditionCreator",
      "Edition",
    ]);
    dynamicSketch = (await ethers.getContractAt(
      "EditionCreator",
      EditionCreator.address
    )) as EditionCreator;

    editionImpl = (await ethers.getContractAt(
      "Edition",
      Edition.address
    )) as Edition;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("does not allow re-initialization of the implementation contract", async () => {
    await expect(
      // @ts-ignore
      editionImpl.initialize(signerAddress, ...DEFAULT_ARGS)
    ).to.be.revertedWith("Initializable: contract is already initialized");
  });

  it("makes a new edition", async () => {
    const minterContract = await createEdition(dynamicSketch, DEFAULT_ARGS);
    expect(await minterContract.name()).to.be.equal(DEFAULT_NAME);
    expect(await minterContract.symbol()).to.be.equal(DEFAULT_SYMBOL);
    expect(await minterContract.imageUrl()).to.equal(DEFAULT_IMAGE_URL);
    expect(await minterContract.animationUrl()).to.equal(DEFAULT_ANIMATION_URL);
    expect(await minterContract.editionSize()).to.equal(DEFAULT_MAX_SUPPLY);
    expect(await minterContract.owner()).to.equal(signerAddress);

    let salePrice = 20000;
    let { receiver, royaltyAmount } = await minterContract.royaltyInfo(/* tokenId */ 1, salePrice);
    expect(receiver).to.equal(signerAddress);
    expect(royaltyAmount).to.equal(salePrice * DEFAULT_ROYALTIES_BPS / 10000);
  });

  it("makes a new edition with both an imageUrl and an animationUrl", async () => {
    const args = [...DEFAULT_ARGS];
    args[3] = "https://example.com/animationUrl";
    args[4] = "https://example.com/imageUrl";

    const edition = await createEdition(dynamicSketch, args);
    expect(await edition.animationUrl()).to.equal(args[3]);
    expect(await edition.imageUrl()).to.equal(args[4]);
  });

  describe("with an edition", () => {
    let signer1: SignerWithAddress;
    let minterContract: Edition;

    beforeEach(async () => {
      signer1 = (await ethers.getSigners())[1];
      minterContract = await createEdition(dynamicSketch, DEFAULT_ARGS);
    });

    describe("custom properties", () => {
      beforeEach(async () => {
        await minterContract.mintEdition(signerAddress);
      });

      it("does not let non-owner set string properties", async () => {
        await expect(
          minterContract.connect(signer1).setStringProperties(["name1", "name2"], ["value1", "value2"])
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("rejects empty property names", async () => {
        await expect(
          minterContract.setStringProperties(["name1", ""], ["value1", "value2"])
        ).to.be.revertedWith("bad attribute");
      });

      it("rejects empty property values", async () => {
        await expect(
          minterContract.setStringProperties(["name1", "name2"], ["value1", ""])
        ).to.be.revertedWith("bad attribute");
      });

      it("rejects string properties where the names and values don't match in length", async () => {
        await expect(
          minterContract.setStringProperties(["name1", "name2"], ["value1"])
        ).to.be.revertedWith("length mismatch");
      });

      it("reflects a single string attribute in the metadata", async () => {
        await expect(minterContract.setStringProperties(["name"], ["value"]))
          .to.emit(minterContract, "PropertyUpdated")
          .withArgs("name", "", "value");
        let metadata = parseMetadataURI(await minterContract.tokenURI(1));

        expect(metadata.properties).to.deep.equal({
          name: "value",
        });
      });

      it("reflects multiple string properties in the metadata", async () => {
        await minterContract.setStringProperties(["name1", "name2"], ["value1", "value2"]);
        let metadata = parseMetadataURI(await minterContract.tokenURI(1));

        expect(metadata.properties).to.deep.equal({
          name1: "value1",
          name2: "value2",
        });
      });

      it("can update create/update/delete a single property", async () => {
        // create
        await expect(minterContract.setStringProperties(["name"], ["initValue"]))
          .to.emit(minterContract, "PropertyUpdated")
          .withArgs("name", "", "initValue");

        // update
        await expect(minterContract.setStringProperties(["name"], ["newValue"]))
          .to.emit(minterContract, "PropertyUpdated")
          .withArgs("name", "initValue", "newValue");

        // delete does not emit an event
        await !expect(minterContract.setStringProperties([], []))
          .to.emit(minterContract, "PropertyUpdated")
          .withArgs("name", "newValue", "");
      });

      it("can set and then erase multiple string properties", async () => {
        // setup: set multiple attributes
        await minterContract.setStringProperties(["name1", "name2"], ["value1", "value2"]);

        // when we set new attributes
        await minterContract.setStringProperties(["name1"], ["newValue"]);
        let metadata = parseMetadataURI(await minterContract.tokenURI(1));

        // then the old ones are either deleted or updated
        expect(metadata.properties).to.deep.equal({
          name1: "newValue", // name 1 has been updated
          // name2 has been deleted
        });

        // when we set attributes to empty arrays
        await minterContract.setStringProperties([], []);
        metadata = parseMetadataURI(await minterContract.tokenURI(1));

        // then they should be removed
        expect(metadata.properties).to.deep.equal({});
      });
    });

    it("has the expected contractURI", async () => {
      const contractURI = await minterContract.contractURI();
      const metadata = parseMetadataURI(contractURI);
      expect(metadata.name).to.equal(DEFAULT_NAME);
      expect(metadata.description).to.equal(DEFAULT_DESCRIPTION);

      expect(metadata.image_url).to.be.undefined;
      expect(metadata.image).to.equal(DEFAULT_IMAGE_URL);
      expect(metadata.seller_fee_basis_points).to.equal(DEFAULT_ROYALTIES_BPS);
      expect(metadata.fee_recipient).to.equal((await minterContract.owner()).toLowerCase());
    });

    describe("during the grace period", () => {
      it("lets the owner call setImageUrl()", async () => {
        const newImageUrl = "https://example.com/newImageUrl";
        await expect(minterContract.setImageUrl(newImageUrl))
          .to.emit(minterContract, "ImageUrlUpdated")
          .withArgs(DEFAULT_IMAGE_URL, newImageUrl);

        expect(await minterContract.imageUrl()).to.equal(newImageUrl);
      });

      it("lets the owner call setAnimationUrl()", async () => {
        const newAnimationUrl = "https://example.com/newAnimationUrl";
        await expect(minterContract.setAnimationUrl(newAnimationUrl))
          .to.emit(minterContract, "AnimationUrlUpdated")
          .withArgs(DEFAULT_ANIMATION_URL, newAnimationUrl);

        expect(await minterContract.animationUrl()).to.equal(newAnimationUrl);
      });

      it("lets the owner call setDescription()", async () => {
        const newDescription = "new description";
        await expect(minterContract.setDescription(newDescription))
          .to.emit(minterContract, "DescriptionUpdated")
          .withArgs(DEFAULT_DESCRIPTION, newDescription);

        expect(await minterContract.description()).to.equal(newDescription);
      });

      it("does not let a non-owner call setAnimationUrl()", async () => {
        await expect(minterContract.connect(signer1).setAnimationUrl(""))
          .to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("does not let a non-owner call setImageUrl()", async () => {
        await expect(minterContract.connect(signer1).setImageUrl(""))
          .to.be.revertedWith("Ownable: caller is not the owner");
      });

      it("does not let a non-owner call setDescription()", async () => {
        await expect(minterContract.connect(signer1).setDescription(""))
          .to.be.revertedWith("Ownable: caller is not the owner");
      });
    });

    describe("after the grace period", () => {
      beforeEach(async () => {
        // warp time forward to after the grace period
        await ethers.provider.send("evm_increaseTime", [DEFAULT_METADATA_GRACE_PERIOD + 1]);
      });

      it("does not let the owner call setImageUrl()", async () => {
        await expect(minterContract.setImageUrl("")).to.be.revertedWith("metadata is frozen");
      });

      it("does not let the owner call setAnimationUrl()", async () => {
        await expect(minterContract.setAnimationUrl("")).to.be.revertedWith("metadata is frozen");
      });

      it("does not let the owner call setDescription()", async () => {
        await expect(minterContract.setDescription("")).to.be.revertedWith("metadata is frozen");
      });

      it("lets the owner call setExternalUrl()", async () => {
        await minterContract.setExternalUrl("https://example.com/externalUrl");
        expect(await minterContract.externalUrl()).to.equal("https://example.com/externalUrl");
      });
    });

    describe("when we set the external URL", () => {
      const externalUrl = "https://example.com/externalUrl";

      beforeEach(async () => {
        await expect(minterContract.setExternalUrl(externalUrl))
          .to.emit(minterContract, "ExternalUrlUpdated").withArgs("", externalUrl);
        expect(await minterContract.externalUrl()).to.equal(externalUrl);
      });

      it("contractURI() reflects it as external_link", async () => {
        const contractURI = await minterContract.contractURI();
        const metadata = parseMetadataURI(contractURI);
        expect(metadata.external_link).to.equal(externalUrl);
      });

      it("tokenURI() reflects it as external_url", async () => {
        await minterContract.mintEdition(signerAddress);
        const tokenURI = await minterContract.tokenURI(1);
        const metadata = parseMetadataURI(tokenURI);
        expect(metadata.external_url).to.equal(externalUrl);
      });

      it("it can be unset", async () => {
        await minterContract.setExternalUrl("");
        expect(await minterContract.externalUrl()).to.equal("");

        // then we no longer see it in contractURI()
        const contractURI = await minterContract.contractURI();
        const metadata = parseMetadataURI(contractURI);
        expect(metadata.external_link).to.be.undefined;

        // and we no longer see it in tokenURI()
        await minterContract.mintEdition(signerAddress);
        const tokenURI = await minterContract.tokenURI(1);
        const tokenMetadata = parseMetadataURI(tokenURI);
        expect(tokenMetadata.external_url).to.be.undefined;
      });

      it("can only be set by the owner", async () => {
        await expect(
          minterContract.connect(signer1).setExternalUrl("https://attacker.com")
        ).to.be.revertedWith("Ownable: caller is not the owner");
      });
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
          name: DEFAULT_NAME + " 1/10",
          description: DEFAULT_DESCRIPTION,
          image: DEFAULT_IMAGE_URL + "?id=1",
          properties: { },
        })
      );
    });

    it("can not create another edition with the same parameters", async () => {
      await expect(createEdition(dynamicSketch, DEFAULT_ARGS)).to.be.revertedWith("ERC1167: create2 failed");
    });

    it("creates an unbounded edition", async () => {
      // no limit for edition size
      let args = [...DEFAULT_ARGS];
      args[0] = "Testing Unbounded Edition";
      args[5] = 0;

      minterContract = await createEdition(dynamicSketch, args);

      const contractURI = await minterContract.contractURI();
      const contractMetadata = parseMetadataURI(contractURI);
      expect(contractMetadata.name).to.equal("Testing Unbounded Edition");
      expect(contractMetadata.description).to.equal(DEFAULT_DESCRIPTION);
      expect(contractMetadata.image).to.equal(DEFAULT_IMAGE_URL);
      expect(contractMetadata.seller_fee_basis_points).to.equal(DEFAULT_ROYALTIES_BPS);
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

      expect(metadata2.name).to.be.equal("Testing Unbounded Edition 2");

      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "Testing Unbounded Edition 1",
          description: DEFAULT_DESCRIPTION,
          image: DEFAULT_IMAGE_URL + "?id=1",
          properties: { },
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
          // @ts-ignore
          ...DEFAULT_ARGS,
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
        let args = [...DEFAULT_ARGS];
        args[0] = "Edition w/ 2% royalties";
        args[6] = 200; // 2% royalties

        const minterContractNew = await createEdition(dynamicSketch, args);
        await minterContractNew.mintEdition(signerAddress);
        expect((await minterContractNew.royaltyInfo(1, ethers.utils.parseEther("1.0")))[1]).to.be.equal(
          ethers.utils.parseEther("0.02")
        );
      });
    });

    it("mints a large batch", async () => {
      // no limit for edition size
      let args = [...DEFAULT_ARGS];
      args[0] = "Unbounded Edition";
      args[5] = 0;

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
      expect(await minterContract.totalSupply()).to.equal(300);
    });

    it("stops after editions are sold out", async () => {
      const [_, signer1] = await ethers.getSigners();

      expect(await minterContract.totalSupply()).to.be.equal(0);
      expect(await minterContract.maxSupply()).to.be.equal(10);

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

      expect(await minterContract.totalSupply()).to.be.equal(10);

      await expect(
        minterContract.mintEdition(signerAddress)
      ).to.be.revertedWith("Sold out");

      const tokenURI = await minterContract.tokenURI(10);
      const metadata = parseMetadataURI(tokenURI);

      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "Testing Token 10/10",
          description: "This is a testing token for all",
          image: DEFAULT_IMAGE_URL + "?id=10",
          properties: { },
        })
      );
    });
  });
});
