import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  EditionCreator,
  Edition,
  IEdition,
} from "../typechain";

const BURN_ADDRESS = "0x000000000000000000000000000000000000dEaD";

const DEFAULT_NAME = "Testing Token";
const DEFAULT_SYMBOL = "TEST";
const DEFAULT_DESCRIPTION = "This is a testing token for all";
const DEFAULT_ANIMATION_URL = "";
const DEFAULT_IMAGE_URL = "ipfs://someImageHash";
const DEFAULT_EDITION_SIZE = 10;
const DEFAULT_ROYALTIES_BPS = 1000;
const DEFAULT_MINT_PERIOD = 0;

function editionArgs(overrides: any = {}) {
  return [
    overrides.name || DEFAULT_NAME,
    overrides.symbol || DEFAULT_SYMBOL,
    overrides.description || DEFAULT_DESCRIPTION,
    overrides.animationUrl || DEFAULT_ANIMATION_URL,
    overrides.imageUrl || DEFAULT_IMAGE_URL,
    overrides.editionSize === undefined ? DEFAULT_EDITION_SIZE : overrides.editionSize,
    overrides.royaltiesBPS === undefined ? DEFAULT_ROYALTIES_BPS : overrides.royaltiesBPS,
    overrides.mintPeriodSeconds === undefined ? DEFAULT_MINT_PERIOD : overrides.mintPeriodSeconds,
  ];
}

function parseMetadataURI(uri: string): any {
  const parsedURI = parseDataURI(uri);
  if (!parsedURI) {
    throw "No parsed uri";
  }

  expect(parsedURI.mimeType.type).to.equal("application");
  expect(parsedURI.mimeType.subtype).to.equal("json");

  // Check metadata from edition
  const uriData = Buffer.from(parsedURI.body).toString("utf-8");
  // console.log("uriData: ", uriData);
  const metadata = JSON.parse(uriData);
  return metadata;
}

describe("Edition", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: EditionCreator;
  let editionImpl: Edition;

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
      editionImpl.initialize(signerAddress, ...editionArgs())
    ).to.be.revertedWith("ALREADY_INITIALIZED");
  });

  it("makes a new edition", async () => {
    const minterContract = await createEdition(dynamicSketch, editionArgs());
    expect(await minterContract.name()).to.be.equal(DEFAULT_NAME);
    expect(await minterContract.symbol()).to.be.equal(DEFAULT_SYMBOL);
    expect(await minterContract.imageUrl()).to.equal(DEFAULT_IMAGE_URL);
    expect(await minterContract.animationUrl()).to.equal(DEFAULT_ANIMATION_URL);
    expect(await minterContract.editionSize()).to.equal(DEFAULT_EDITION_SIZE);
    expect(await minterContract.owner()).to.equal(signerAddress);

    let salePrice = 20000;
    let { receiver, royaltyAmount } = await minterContract.royaltyInfo(/* tokenId */ 1, salePrice);
    expect(receiver).to.equal(signerAddress);
    expect(royaltyAmount).to.equal(salePrice * DEFAULT_ROYALTIES_BPS / 10000);
  });

  it("makes a new edition with both an imageUrl and an animationUrl", async () => {
    const overrides = {
      animationUrl: "https://example.com/animationUrl",
      imageUrl: "https://example.com/imageUrl",
    };

    const edition = await createEdition(dynamicSketch, editionArgs(overrides));
    expect(await edition.animationUrl()).to.equal(overrides.animationUrl);
    expect(await edition.imageUrl()).to.equal(overrides.imageUrl);

    await edition.mintEdition(signerAddress);
    const metadata = parseMetadataURI(await edition.tokenURI(1));
    expect(metadata.animation_url).to.equal(overrides.animationUrl);
    expect(metadata.image).to.equal(overrides.imageUrl);
  });

  describe("with an edition", () => {
    let signer1: SignerWithAddress;
    let signer2: SignerWithAddress;
    let minterContract: Edition;

    beforeEach(async () => {
      signer1 = (await ethers.getSigners())[1];
      signer2 = (await ethers.getSigners())[2];
      minterContract = await createEdition(dynamicSketch, editionArgs());
    });

    describe("custom properties", () => {
      beforeEach(async () => {
        await minterContract.mintEdition(signerAddress);
      });

      it("does not let non-owner set string properties", async () => {
        await expect(
          minterContract.connect(signer1).setStringProperties(["name1", "name2"], ["value1", "value2"])
        ).to.be.revertedWith("UNAUTHORIZED");
      });

      it("rejects empty property names", async () => {
        await expect(
          minterContract.setStringProperties(["name1", ""], ["value1", "value2"])
        ).to.be.revertedWith("BadAttribute");
      });

      it("rejects empty property values", async () => {
        await expect(
          minterContract.setStringProperties(["name1", "name2"], ["value1", ""])
        ).to.be.revertedWith("BadAttribute");
      });

      it("rejects string properties where the names and values don't match in length", async () => {
        await expect(
          minterContract.setStringProperties(["name1", "name2"], ["value1"])
        ).to.be.revertedWith("LengthMismatch");
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
        ).to.be.revertedWith("UNAUTHORIZED");
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
          name: DEFAULT_NAME + " #1/10",
          description: DEFAULT_DESCRIPTION,
          image: DEFAULT_IMAGE_URL,
          properties: { },
        })
      );
    });

    it("can not create another edition with the same parameters", async () => {
      await expect(createEdition(dynamicSketch, editionArgs())).to.be.revertedWith("ERC1167: create2 failed");
    });

    it("creates an unbounded edition", async () => {
      const overrides = {
        name: "Unbounded Edition",
        editionSize: 0,
      };

      minterContract = await createEdition(dynamicSketch, editionArgs(overrides));

      const contractURI = await minterContract.contractURI();
      const contractMetadata = parseMetadataURI(contractURI);
      expect(contractMetadata.name).to.equal(overrides.name);
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

      expect(metadata2.name).to.be.equal(`${overrides.name} #2`);

      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: `${overrides.name} #1`,
          description: DEFAULT_DESCRIPTION,
          image: DEFAULT_IMAGE_URL,
          properties: { },
        })
      );
    });

    it("creates an authenticated edition", async () => {
      await minterContract.mintEdition(await signer1.address);
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.address
      );
    });

    it("allows user burn", async () => {
      await minterContract.mintEdition(await signer1.address);
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.address
      );

      await minterContract.connect(signer1).transferFrom(signer1.address, BURN_ADDRESS, 1);
      expect(await minterContract.ownerOf(1)).to.equal(BURN_ADDRESS);
    });

    it("updates totalSupply()", async () => {
      // setup:
      expect(await minterContract.totalSupply()).to.equal(0);

      // when we mint
      await minterContract.mintEdition(await signer1.address);

      // then totalSupply is updated
      expect(await minterContract.totalSupply()).to.equal(1);
    });

    it("allows burn if approved", async () => {
      await minterContract.mintEdition(await signer1.address);
      await minterContract.connect(signer1).approve(signer2.address, 1);
      await expect(minterContract.connect(signer2).transferFrom(signer1.address, BURN_ADDRESS, 1)).to.emit(minterContract, "Transfer");
      expect(await minterContract.ownerOf(1)).to.equal(BURN_ADDRESS);
    });

    it("allows burn if approved for all", async () => {
      await minterContract.mintEdition(await signer1.address);
      await minterContract.connect(signer1).setApprovalForAll(signer2.address, true);
      await expect(minterContract.connect(signer2).transferFrom(signer1.address, BURN_ADDRESS, 1)).to.emit(minterContract, "Transfer");
    });

    it("does not allow burn if non approved", async () => {
      await minterContract.mintEdition(await signer1.address);

      await expect(minterContract.connect(signer2).transferFrom(signer1.address, BURN_ADDRESS, 1)).to.be.revertedWith("NOT_AUTHORIZED");
    });

    it("does not allow to burn the same token twice", async () => {
      await minterContract.mintEdition(signerAddress);
      await minterContract.transferFrom(signerAddress, BURN_ADDRESS, 1);

      // the owner is now 0xdEaD, which is unspendable
      await expect(minterContract.transferFrom(signer1.address, BURN_ADDRESS, 1)).to.be.revertedWith("WRONG_FROM");
    });

    it("does not allow re-initialization", async () => {
      await expect(
        minterContract.initialize(
          signerAddress,
          // @ts-ignore
          ...editionArgs(),
        )
      ).to.be.revertedWith("ALREADY_INITIALIZED");

      await minterContract.mintEdition(await signer1.getAddress());
      expect(await minterContract.ownerOf(1)).to.equal(
        await signer1.getAddress()
      );
    });

    it("mints in batches", async () => {
      const [s1, s2, s3] = await ethers.getSigners();
      await minterContract.mintEditions([
        s1.address,
        s2.address,
        s3.address,
      ]);
      expect(await minterContract.ownerOf(1)).to.equal(s1.address);
      expect(await minterContract.ownerOf(2)).to.equal(s2.address);
      expect(await minterContract.ownerOf(3)).to.equal(s3.address);
      await minterContract.mintEditions([
        s1.address,
        s2.address,
        s3.address,
        s2.address,
        s3.address,
        s2.address,
        s3.address,
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
        const overrides = {
          name: "Edition w/ 2% royalties",
          royaltiesBPS: 200,
        };

        const minterContractNew = await createEdition(dynamicSketch, editionArgs(overrides));
        await minterContractNew.mintEdition(signerAddress);
        expect((await minterContractNew.royaltyInfo(1, ethers.utils.parseEther("1.0")))[1]).to.be.equal(
          ethers.utils.parseEther("0.02")
        );
      });
    });

    it("mints a large batch", async () => {
      const overrides = {
        name: "Unbounded Edition",
        editionSize: 0,
      };

      minterContract = await createEdition(dynamicSketch, editionArgs(overrides));

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
      ).to.be.revertedWith("SoldOut");

      const tokenURI = await minterContract.tokenURI(10);
      const metadata = parseMetadataURI(tokenURI);

      expect(JSON.stringify(metadata)).to.equal(
        JSON.stringify({
          name: "Testing Token #10/10",
          description: "This is a testing token for all",
          image: DEFAULT_IMAGE_URL,
          properties: { },
        })
      );
    });
  });

  describe("an edition that uses special characters", () => {
    let edition: Edition;
    const expectedName = "My \"edition\" is \t very special!\n";
    const expectedDescription = "My \"description\" is also \t \\very\\ special!\r\n";

    beforeEach(async () => {
      const overrides = {
        name: expectedName,
        description: expectedDescription,
      };

      // @ts-ignore
      edition = await createEdition(dynamicSketch, editionArgs(overrides));
    });

    it("returns the correct name", async () => {
      expect(await edition.name()).to.equal(expectedName);
    });

    it("returns the correct description", async () => {
      expect(await edition.description()).to.equal(expectedDescription);
    });

    it("returns the correct contractURI", async () => {
      let contractURI = await edition.contractURI();
      let metadata = parseMetadataURI(contractURI);
      expect(metadata.name).to.equal(expectedName);
      expect(metadata.description).to.equal(expectedDescription);
    });

    it("returns the correct tokenURI", async () => {
      await edition.mintEdition(signerAddress);
      let tokenURI = await edition.tokenURI(1);
      let metadata = parseMetadataURI(tokenURI);
      expect(metadata.name).to.equal(expectedName + " #1/10");
      expect(metadata.description).to.equal(expectedDescription);
    });

    it("can escape string properties correctly", async () => {
      // when we set a property with a special character
      await edition.setStringProperties(["creator"], ['Jeffrey "The Dude" Lebowski']);
      await edition.mintEdition(signerAddress);

      // then we can recover it from the parsed metadata (meaning that it was escaped correctly)
      let tokenURI = await edition.tokenURI(1);
      let metadata = parseMetadataURI(tokenURI);
      expect(metadata.properties.creator).to.equal('Jeffrey "The Dude" Lebowski');
    });
  });

  describe("an open edition with a limited minting period", () => {
    let edition: Edition;
    const mintingPeriod = 60 * 60 * 24 * 7; // 1 week

    beforeEach(async () => {
      const overrides = {
        name: "Open Edition with Minting Period",
        editionSize: 0,
        mintPeriodSeconds: mintingPeriod,
      };

      // @ts-ignore
      edition = await createEdition(dynamicSketch, editionArgs(overrides));
    });

    describe("during the minting period", () => {
      it("allows minting", async () => {
        await expect(edition.mintEdition(signerAddress)).to.emit(edition, "Transfer")
      });

      it("returns the expected totalSupply()", async () => {
        await edition.mintEdition(signerAddress);
        expect(await edition.totalSupply()).to.equal(1);
      });

      it("isMintingEnded() returns false", async () => {
        expect(await edition.isMintingEnded()).to.equal(false);
      });

      it("returns the expected tokenURI", async () => {
        await edition.mintEdition(signerAddress);
        const tokenURI = await edition.tokenURI(1);
        const metadata = parseMetadataURI(tokenURI);
        expect(metadata.name).to.equal("Open Edition with Minting Period #1");
      });
    });

    describe("after the minting period", () => {
      beforeEach(async () => {
        // mint one
        await edition.mintEdition(signerAddress);

        // warp forward in time
        await ethers.provider.send("evm_increaseTime", [mintingPeriod + 60]);
        await ethers.provider.send("evm_mine", []);
      });

      it("does not allow minting", async () => {
        await expect(edition.mintEdition(signerAddress)).to.be.revertedWith("MintingEnded");
      });

      it("does not allow minting multiple", async () => {
        await expect(edition.mintEditions([signerAddress, signerAddress])).to.be.revertedWith("MintingEnded");
      });

      it("does not allow purchasing", async () => {
        const salePrice = ethers.utils.parseEther("0.1");
        await edition.setSalePrice(salePrice);
        await expect(edition.mintEdition(signerAddress)).to.be.revertedWith("MintingEnded");
        await expect(edition.safeMintEdition(signerAddress)).to.be.revertedWith("MintingEnded");
        await expect(edition.mintEditions([signerAddress, signerAddress])).to.be.revertedWith("MintingEnded");
      });

      it("returns the expected totalSupply()", async () => {
        expect(await edition.totalSupply()).to.equal(1);
      });

      it("isMintingEnded() returns true", async () => {
        expect(await edition.isMintingEnded()).to.equal(true);
      });

      it("returns the expected tokenURI", async () => {
        const tokenURI = await edition.tokenURI(1);
        const metadata = parseMetadataURI(tokenURI);
        expect(metadata.name).to.equal("Open Edition with Minting Period #1");
      });
    });
  });


  describe("a limited edition with a limited minting period", () => {
    let edition: Edition;
    const mintingPeriod = 60 * 60 * 24 * 7; // 1 week

    beforeEach(async () => {
      const overrides = {
        name: "Limited Edition with Minting Period",
        mintPeriodSeconds: mintingPeriod,
      };

      // @ts-ignore
      edition = await createEdition(dynamicSketch, editionArgs(overrides));
    });

    describe("during the minting period", () => {
      it("allows minting", async () => {
        await expect(edition.mintEdition(signerAddress)).to.emit(edition, "Transfer")
      });

      it("returns the expected totalSupply()", async () => {
        await edition.mintEdition(signerAddress);
        expect(await edition.totalSupply()).to.equal(1);
      });

      it("isMintingEnded() returns false", async () => {
        expect(await edition.isMintingEnded()).to.equal(false);
      });
    });

    describe("after the minting period", () => {
      beforeEach(async () => {
        // mint one
        await edition.mintEdition(signerAddress);

        // warp forward in time
        await ethers.provider.send("evm_increaseTime", [mintingPeriod + 60]);
        await ethers.provider.send("evm_mine", []);
      });

      it("does not allow minting", async () => {
        await expect(edition.mintEdition(signerAddress)).to.be.revertedWith("MintingEnded");
      });

      it("does not allow minting multiple", async () => {
        await expect(edition.mintEditions([signerAddress, signerAddress])).to.be.revertedWith("MintingEnded");
      });

      it("does not allow purchasing", async () => {
        const salePrice = ethers.utils.parseEther("0.1");
        await edition.setSalePrice(salePrice);
        await expect(edition.mintEdition(signerAddress)).to.be.revertedWith("MintingEnded");
        await expect(edition.safeMintEdition(signerAddress)).to.be.revertedWith("MintingEnded");
        await expect(edition.mintEditions([signerAddress, signerAddress])).to.be.revertedWith("MintingEnded");
      });

      it("returns the expected totalSupply()", async () => {
        expect(await edition.totalSupply()).to.equal(1);
      });

      it("isMintingEnded() returns true", async () => {
        expect(await edition.isMintingEnded()).to.equal(true);
      });
    });
  });
});
