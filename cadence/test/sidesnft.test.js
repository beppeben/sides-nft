import path from "path";
import {emulator, init, getAccountAddress, mintFlow, getFlowBalance,
        deployContractByName, getContractAddress, sendTransaction, executeScript} from "flow-js-testing";

jest.setTimeout(100000);

async function deployAll() {
  var [deploymentResult, error] = await deployContractByName({name: "NonFungibleToken"});
  var [deploymentResult, error] = await deployContractByName({name: "MetadataViews"});
  const NonFungibleToken = await getContractAddress("NonFungibleToken");
  const MetadataViews = await getContractAddress("MetadataViews");

  [deploymentResult, error] = await deployContractByName({name: "SidesNFT", addressMap: {NonFungibleToken, MetadataViews}, args: []});
    
  console.log(error)
}

describe("sidesnft", ()=>{
  beforeEach(async () => {
    const basePath = path.resolve(__dirname, ".."); 
    const port = 8081; 
    const logging = true;
    
    await init(basePath, { port });
    return emulator.start(port, logging);
  });
  
  afterEach(async () => {
    return emulator.stop();
  });

  
  test("sidesnft", async () => {    
    await deployAll();
    
    // actors' addresses
    const alice = await getAccountAddress("Alice");
    const bob = await getAccountAddress("Bob");
    
    
    // give some flow to users
    await mintFlow(alice, 50.0);
    await mintFlow(bob, 50.0);

    // Try to mint 3 Level-0 NFTs with the wrong price
    var [tx, error] = await sendTransaction("mint_level_0", [alice], [3, 1.0]);
    expect(error).not.toBeNull();
    
    // Try to mint 11 (too many) Level-0 NFTs
    var [tx, error] = await sendTransaction("mint_level_0", [alice], [11, 11.0]);
    expect(error).not.toBeNull();

    // Try mint 4 Level-0 NFTs with the correct price
    var [tx, error] = await sendTransaction("mint_level_0", [alice], [4, 4.0]);
    expect(error).toBeNull();

    // Verify that Alice holds the minted NFTs
    var [result,error] = await executeScript("read_collection", [alice]);
    expect(result.length).toEqual(4);
    expect(result[0].level).toEqual(0);
    expect(error).toBeNull();

    // Verify collection stats
    var [result,error] = await executeScript("read_stats", []);
    expect(result).toEqual(
    {
      totalSupplyByLevel: { '0': 4 },
      totalGrossSupply: 4,
      totalLevel0Minted: 4,
      maxMintableLevel: 1,
      lastMintedImage: 'img_0_0'
    })

    // Mint 5 more from bob
    var [tx, error] = await sendTransaction("mint_level_0", [bob], [5, 5.0]);
    expect(error).toBeNull();

    // Mint 6 more from bob (should give an error, max is 10)
    var [tx, error] = await sendTransaction("mint_level_0", [bob], [6, 6.0]);
    expect(error).not.toBeNull();

    // Verify that Bob holds the minted NFTs
    var [result,error] = await executeScript("read_collection", [bob]);
    expect(result.length).toEqual(5);

    // Verify collection stats
    var [result,error] = await executeScript("read_stats", []);
    expect(result).toEqual(
    {
      totalSupplyByLevel: { '0': 9 },
      totalGrossSupply: 9,
      totalLevel0Minted: 9,
      maxMintableLevel: 2,
      lastMintedImage: 'img_0_2'
    })

    // Try to mint a Level-2 NFT (should give an error as we don't have any Level-1)
    var [tx, error] = await sendTransaction("evolve", [bob], [2]);
    expect(error).not.toBeNull();

    // Evolve 3 Level-0 to a Level-1
    var [tx, error] = await sendTransaction("evolve", [bob], [1]);
    expect(error).toBeNull();

    // Verify that Bob's collection has changed
    var [result,error] = await executeScript("read_collection", [bob]);
    expect(result.length).toEqual(3);

    // Try to do it again (should result in an error as we only have 2 Level-0 left)
    var [tx, error] = await sendTransaction("evolve", [bob], [1]);
    expect(error).not.toBeNull();

    // Verify collection stats
    var [result,error] = await executeScript("read_stats", []);
    expect(result).toEqual(
    {
      totalSupplyByLevel: { '0': 6, '1': 1 },
      totalGrossSupply: 10,
      totalLevel0Minted: 9,
      maxMintableLevel: 2,
      lastMintedImage: 'img_1_0'
    })

    // Verify total supply
    var [result,error] = await executeScript("read_supply", []);
    expect(result).toEqual(7)

    // Downgrade one NFT of level 1 for 2 Level-0
    var [tx, error] = await sendTransaction("downgrade", [bob], [0]);
    expect(error).toBeNull();

    // Verify collection stats
    var [result,error] = await executeScript("read_stats", []);
    expect(result).toEqual(
    {
      totalSupplyByLevel: { '0': 8, '1': 0 },
      totalGrossSupply: 12,
      totalLevel0Minted: 9,
      maxMintableLevel: 2,
      lastMintedImage: 'img_0_2'
    })

    // Verify that Bob's collection has changed
    var [result,error] = await executeScript("read_collection", [bob]);
    expect(result.length).toEqual(4);

    // Verify total supply
    var [result,error] = await executeScript("read_supply", []);
    expect(result).toEqual(8)


  })

})
