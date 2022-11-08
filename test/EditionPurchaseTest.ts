import { expect } from "chai";
import "@nomiclabs/hardhat-ethers";
import { ethers, deployments } from "hardhat";
import parseDataURI from "data-urls";

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import {
  EditionCreator,
  Edition,
} from "../typechain";

describe("Edition", () => {
  let signer: SignerWithAddress;
  let signerAddress: string;
  let dynamicSketch: EditionCreator;

  beforeEach(async () => {
    const { EditionCreator } = await deployments.fixture([
      "EditionCreator",
      "Edition",
    ]);
    const dynamicAddress = (
      await deployments.get("Edition")
    ).address;
    dynamicSketch = (await ethers.getContractAt(
      "EditionCreator",
      EditionCreator.address
    )) as EditionCreator;

    signer = (await ethers.getSigners())[0];
    signerAddress = await signer.getAddress();
  });

  it("purchases a edition", async () => {
    let createEdition = async function(factory: EditionCreator, args: any): Promise<Edition> {
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

    const minterContract = await createEdition(dynamicSketch, [
      "Testing Token",
      "TEST",
      "This is a testing token for all",
      "https://ipfs.io/ipfsbafybeify52a63pgcshhbtkff4nxxxp2zp5yjn2xw43jcy4knwful7ymmgy",
      "",
      10, // 10 editions
      10, // royalties
      0, // mint period
    ]);
    expect(await minterContract.name()).to.be.equal("Testing Token");
    expect(await minterContract.symbol()).to.be.equal("TEST");

    const [_, s2] = await ethers.getSigners();

    // only the owner can set the sale price
    await expect(
      minterContract.connect(s2).setSalePrice(ethers.utils.parseEther("0.2"))
    ).to.be.revertedWith("UNAUTHORIZED");

    // when the owner calls setSalePrice, we emit an event
    await expect(
      minterContract.setSalePrice(ethers.utils.parseEther("0.2"))
    ).to.emit(minterContract, "PriceChanged");

    // only approved minters can mint
    await expect(minterContract.connect(s2).mintEdition(signerAddress, { value: ethers.utils.parseEther("0.2") })).to.be.revertedWith("Unauthorized");

    // open the public sale
    await minterContract.setApprovedMinter(ethers.constants.AddressZero, true);

    await expect(
      minterContract
        .connect(s2)
        .mintEdition(signerAddress, { value: ethers.utils.parseEther("0.2") })
    ).to.emit(minterContract, "Transfer");

    const signerBalance = await signer.getBalance();
    await minterContract.withdraw();
    // Some ETH is lost from withdraw contract interaction.
    expect(
      (await signer.getBalance())
        .sub(signerBalance)
        .gte(ethers.utils.parseEther('0.19'))
    ).to.be.true;
  });
});
