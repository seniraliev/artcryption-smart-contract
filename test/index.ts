import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

var weth: any;
var singleNFT: any;
var multipleNFT: any;
var ownerShip: any;
var license: any;
var marketplace: any;
var content: any;
var owner: any;
var user: any;
var buyer: any;
const uri = "https://gateway.pinata.cloud/ipfs/Qme2AwawrQoBYbE21UPQtfSkcZ3KYAQMMh6z61paJ4i4bw";

describe("SingleNFT", function () {
  it("Should return same address with one that minted NFT", async function () {
    [owner, user, buyer] = await ethers.getSigners()
    const SingleNFT = await ethers.getContractFactory("SingleNFT");
    singleNFT = await upgrades.deployProxy(SingleNFT, [
      "My NFT",
      "MNFT"
    ], {
      initializer: "initialize",
    });
    await singleNFT.deployed();
    
    const mintRole = await singleNFT.MINTER_ROLE();

    var tx = await singleNFT.grantRole(mintRole, user.address);
    await tx.wait();

    expect(await singleNFT.hasRole(mintRole, user.address)).to.equal(true);

    tx = await singleNFT.connect(user).create(user.address, uri);
    await tx.wait();

    expect(await singleNFT.ownerOf("1")).to.equal(user.address);
  });
});

describe("MultiNFT", function () {
  it("Should return same address with one that minted NFT", async function () {
    const MultiNFT = await ethers.getContractFactory("MultiNFT");
    multipleNFT = await upgrades.deployProxy(MultiNFT, [
      "My NFT",
      "MNFT",
      ""
    ], {
      initializer: "initialize",
    });
    await multipleNFT.deployed();

    const mintRole = await multipleNFT.MINTER_ROLE();

    var tx = await multipleNFT.grantRole(mintRole, user.address);
    await tx.wait();

    expect(await multipleNFT.hasRole(mintRole, user.address)).to.equal(true);

    tx = await multipleNFT.connect(user).create(user.address, "10", uri, ethers.utils.hexlify(1));
    await tx.wait();

    expect(await multipleNFT.creatorOf("1")).to.equal(user.address);
  });
});

describe("OwnershipCertificate", function () {
  it("Should return same address with one that minted NFT", async function () {
    const OwnershipCertificate = await ethers.getContractFactory("OwnershipCertificate");
    ownerShip = await upgrades.deployProxy(OwnershipCertificate, [], {
      initializer: "initialize",
    });
    await ownerShip.deployed();

    const governerRole = await ownerShip.GOVERNER_ROLE();
    var tx = await ownerShip.grantRole(governerRole, owner.address);
    tx = await ownerShip.grantRole(governerRole, user.address);
    tx = await ownerShip.grantRole(governerRole, buyer.address);

    expect(await ownerShip.hasRole(governerRole, owner.address)).to.equal(true);
  });
});

describe("License", async function () {
  it("Should return buyer address after license is granted", async function () {
    const License = await ethers.getContractFactory("License");
    license = await upgrades.deployProxy(License, [], {
      initializer: "initialize",
    });
    await license.deployed();
    var tx = await license.connect(user).grantLicense(singleNFT.address, 1, 1, buyer.address);
    await tx.wait();
    expect(await license.isLicensed(singleNFT.address, 1, buyer.address)).to.equal(true);
  });
});

describe("Marketplace", function () {
  it("Should return buyer address after license is granted", async function () {
    const MockWETH = await ethers.getContractFactory("MockWETH");
    weth = await MockWETH.deploy(buyer.address, user.address);
    await weth.deployed();

    const Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await upgrades.deployProxy(Marketplace, [
      weth.address, 
      singleNFT.address, 
      multipleNFT.address, 
      ownerShip.address, 
      license.address,
      owner.address
    ], {
      initializer: "initialize",
    });
    await marketplace.deployed();
    weth.connect(user).approve(marketplace.address, "100000000000000000000")
    weth.connect(buyer).approve(marketplace.address, "100000000000000000000")

    tx = await singleNFT.connect(user).setApprovalForAll(marketplace.address, true)
    await tx.wait();

    var tx = await marketplace.connect(user).addAssetForFixedSale({
      assetType:1, 
      seller: user.address, 
      creator: user.address, 
      tokenAddress: singleNFT.address, 
      tokenId: 1, 
      quantity: 1, 
      price:"100000000000000", 
      uri: uri,
      stakeholders:[], 
      royaltySplit:[]
    }, false, uri);
    await tx.wait();

    const governerRole = await ownerShip.GOVERNER_ROLE();
    tx = await ownerShip.grantRole(governerRole, marketplace.address);
    tx = await marketplace.connect(buyer).buy(1, true);
    await tx.wait();
  });

  it("Should add AssetForDutchAuction", async function () {
    tx = await singleNFT.connect(buyer).setApprovalForAll(marketplace.address, true)
    await tx.wait();

    var tx = await marketplace.connect(buyer).addAssetForDutchAuction({
      assetType:1, 
      seller: buyer.address, 
      creator: buyer.address, 
      tokenAddress: singleNFT.address, 
      tokenId: 1, 
      quantity: 1, 
      price:"100000000000000", 
      uri: uri,
      stakeholders:[], 
      royaltySplit:[]
    },{
      startingPrice: "100000000000000",
      startAt: "1655296910000",
      expiresAt: "1655521429000",
      discountRate: "1"
    }, false, uri);
    await tx.wait();
  });
  
  // it("Should add AssetForEnglishAuction", async function () {
  //   tx = await singleNFT.connect(buyer).setApprovalForAll(marketplace.address, true)
  //   await tx.wait();

  //   var tx = await marketplace.connect(buyer).addAssetForEnglishAuction({
  //     assetType:1, 
  //     seller: buyer.address, 
  //     creator: buyer.address, 
  //     tokenAddress: singleNFT.address, 
  //     tokenId: 1, 
  //     quantity: 1, 
  //     price:"100000000000000", 
  //     uri: uri,
  //     stakeholders:[], 
  //     royaltySplit:[]
  //   }, "100000000000000", "100000000", false, uri);
  //   await tx.wait();

    
  //   tx = await marketplace.connect(buyer).pauseSale(1);
  //   await tx.wait();

  //   tx = await marketplace.connect(buyer).unpauseSale(1);
  //   await tx.wait();

  //   tx = await marketplace.connect(buyer).startAuction(1);
  //   await tx.wait();

  //   tx = await marketplace.connect(user).bid(1, "90000000000000");
  //   await tx.wait();
    
  //   tx = await marketplace.connect(buyer).endAuction(1);
  //   await tx.wait();
  // });
});