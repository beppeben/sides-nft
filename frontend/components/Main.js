import "../flow/config";
import { useState, useEffect } from "react";
import * as fcl from "@onflow/fcl";
import { Transaction } from "./Transaction";


function App() {
  const [user, setUser] = useState({ loggedIn: null })
  const [flowBalance, setFlowBalance] = useState(null)
  const [stats, setStats] = useState(null)
  const [numLevel0ToMint, setNumLevel0ToMint] = useState(null)
  const [upgradeToLevel, setUpgradeToLevel] = useState(null)
  const [downgradeFromLevel, setDowngradeFromLevel] = useState(null)
  const [level0LeftToMint, setLevel0LeftToMint] = useState(null)
  const [myIds, setMyIds] = useState(null)
  const [myImgs, setMyImgs] = useState(null)
  const [myLevels, setMyLevels] = useState(null)
  const [transactionInProgress, setTransactionInProgress] = useState(false)
  const [transactionStatus, setTransactionStatus] = useState(null)
  const [transactionError, setTransactionError] = useState(null)
  const [txId, setTxId] = useState(null)

  
  // Get flow balance and collection info after login
  async function onAuthenticate(user) {
    setUser(user)
    if (user?.addr != null) {
      const account = await fcl.account(user.addr);
      setFlowBalance(Math.round(account.balance / 100000000 * 100) / 100);
      getCollection(user?.addr)
      getLevel0LeftToMint(user?.addr)
    } 
  }
  
  // Get general collection's stats at page load
  useEffect(() => {fcl.currentUser.subscribe(onAuthenticate)
                   getStats()}, [])


  const logOut = async () => {
    const logout = await fcl.unauthenticate()
    setUser(null)
  }

  
  // Refresh after transaction is confirmed
  async function updateTx(res) {
    setTransactionStatus(res.status)
    setTransactionError(res.errorMessage)
    if (res.status === 4) {
      onAuthenticate(user)
      getStats()
      getCollection(getCollection(user?.addr))
      getLevel0LeftToMint(user?.addr)
    }
  }


  function initTransactionState() {
    setTransactionInProgress(true)
    setTransactionStatus(-1)
    setTransactionError(null)
  }


  function hideTx() {
    setTransactionInProgress(false)
  }


  
  // Retrieve the number of Level-0 NFTs still available to mint for the user
  const getLevel0LeftToMint = async (address) => {
    if (address == null) {
      return
    }
    try{
      const num = await fcl.query({
        cadence: `
          import SidesNFT from 0xSidesNFT

          pub fun main(account: Address): UInt32 {
              return SidesNFT.getLevel0LeftToMint(address: account)
          }
        `,
        args: (arg, t) => [
          arg(address, t.Address)
        ]
      })

      setLevel0LeftToMint(num)

    } catch(e){console.log(e)}
  }


  // Retrieve the user's NFT collection
  const getCollection = async (address) => {
    if (address == null) {
      return
    }
    try{
      const nfts = await fcl.query({
        cadence: `
          import NonFungibleToken from 0xNonFungibleToken
          import SidesNFT from 0xSidesNFT

          pub fun main(account: Address): [&SidesNFT.NFT] {
              let collectionRef = getAccount(account)
                  .getCapability(SidesNFT.CollectionPublicPath)
                  .borrow<&SidesNFT.Collection{SidesNFT.CollectionPublic}>()
                  ?? panic("Could not get reference to the NFT Collection")

              var nfts: [&SidesNFT.NFT] = []
              for id in collectionRef.getIDs() {
                  nfts.append(collectionRef.borrowSidesNFT(id: id)!)
              }

              return nfts
          }
        `,
        args: (arg, t) => [
          arg(address, t.Address)
        ]
      })
      var ids = []
      var levels = []
      var imgs = []
      for (let i in nfts) {
        ids.push(nfts[i].id)
        levels.push(nfts[i].level)
        imgs.push(nfts[i].thumbnail)
      }
      setMyIds(ids)
      setMyLevels(levels)
      setMyImgs(imgs)

    } catch(e){console.log(e)}
  }


  // Retrieve general collection's statistics
  const getStats = async () => {
    try{
      const stats = await fcl.query({
        cadence: `
          import SidesNFT from 0xSidesNFT

          pub fun main(): SidesNFT.Stats {
              return SidesNFT.stats
          }
        `,
        args: (arg, t) => []
      })
      var supplyNums = []
      for (let i = 0; i <= stats.maxMintableLevel; i++) {
        if (i in stats.totalSupplyByLevel) {
          supplyNums.push(stats.totalSupplyByLevel[i])
        }
      }
      setStats([supplyNums, stats.totalGrossSupply, stats.totalLevel0Minted, stats.maxMintableLevel, stats.lastMintedImage])

    } catch(e){console.log(e)}
  }

  
  // Downgrade an NFT to a set of NFTs of the previous level
  const downgradeNFT = async () => {

    if(downgradeFromLevel == null) {
      downgradeFromLevel = 1
    }

    initTransactionState()
    const transactionId = await fcl.mutate({
      cadence: `

        import SidesNFT from 0xSidesNFT

        transaction(toLevel: UInt32) {

            let collection: &SidesNFT.Collection
            let address: Address

            prepare(signer: AuthAccount) {
                self.collection = signer.borrow<&SidesNFT.Collection>(from: SidesNFT.CollectionStoragePath)
                            ?? panic("Could not borrow a reference to the collection")

                self.address = signer.address
            }

            execute {
                let fromLevel = toLevel + UInt32(1)
                // downgrade the first NFT found with the required level.
                // in future versions we may let the user choose which NFT to downgrade
                // (already supported by the contract)
                var success = false
                for id in self.collection.getIDs() {
                    if self.collection.borrowSidesNFT(id: id)!.level == fromLevel {
                        let nft <- self.collection.withdraw(withdrawID: id) as! @SidesNFT.NFT
                        SidesNFT.downgradeNFTs(fromNFT: <-nft, address: self.address)
                        success = true
                        break
                    }
                }
                if !success {
                    panic("No NFT found with the required level.")
                }
            }
        }

      `,
      args: (arg, t) => [
        arg(downgradeFromLevel-1, t.UInt32)
      ],
      payer: fcl.authz,
      proposer: fcl.authz,
      authorizations: [fcl.authz],
      limit: 1000
    })
    setTxId(transactionId);
    fcl.tx(transactionId).subscribe(updateTx)
  }


  // Upgrade a set of NFTs (of the same level) to one NFT of the level above
  const upgradeNFT = async () => {

    if(upgradeToLevel == null) {
      upgradeToLevel = 1
    }

    initTransactionState()
    const transactionId = await fcl.mutate({
      cadence: `
        import SidesNFT from 0xSidesNFT

        transaction(toLevel: UInt32) {

            let collection: &SidesNFT.Collection
            let address: Address

            prepare(signer: AuthAccount) {
                self.collection = signer.borrow<&SidesNFT.Collection>(from: SidesNFT.CollectionStoragePath)
                            ?? panic("Could not borrow a reference to the collection")

                self.address = signer.address
            }

            execute {
                let fromLevel = toLevel - UInt32(1)
                let numEvolve = SidesNFT.configs.numEvolve
                var nfts: @[SidesNFT.NFT] <- []
                // in future versions we may let the users choose which NFTs to burn
                // (already supported by the contract)
                for id in self.collection.getIDs() {
                    if self.collection.borrowSidesNFT(id: id)!.level == fromLevel && UInt32(nfts.length) < numEvolve {
                        let nft <- self.collection.withdraw(withdrawID: id) as! @SidesNFT.NFT
                        nfts.append(<-nft)
                    }
                }
                SidesNFT.evolveNFTs(fromNFTs: <-nfts, address: self.address)
            }
        }
 
      `,
      args: (arg, t) => [
        arg(upgradeToLevel, t.UInt32)
      ],
      payer: fcl.authz,
      proposer: fcl.authz,
      authorizations: [fcl.authz],
      limit: 1000
    })
    setTxId(transactionId);
    fcl.tx(transactionId).subscribe(updateTx)
  }


  // Mint NFTs of the base (Level-0) level
  const mintLevel0 = async () => {

    if(numLevel0ToMint == null) {
      numLevel0ToMint = 1
    }
    
    initTransactionState()
    const transactionId = await fcl.mutate({
      cadence: `
        import SidesNFT from 0xSidesNFT
        import FlowToken from 0xFlowToken

        transaction(num: UInt32, price: UFix64) {

            let vault: @FlowToken.Vault
            let address: Address

            prepare(signer: AuthAccount) {
                // withdraw Flow
                let mainVault = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
                            ?? panic("Could not borrow a reference to the flow vault")
                self.vault <- mainVault.withdraw(amount: price) as! @FlowToken.Vault
                self.address = signer.address

                // initialize collection
                if (signer.getCapability(SidesNFT.CollectionPublicPath)
                    .borrow<&SidesNFT.Collection{SidesNFT.CollectionPublic}>() == nil) {
                    // Create a Collection resource and save it to storage
                    let collection <- SidesNFT.createEmptyCollection()
                    signer.save(<-collection, to: SidesNFT.CollectionStoragePath)

                    // create a public capability for the collection
                    signer.link<&SidesNFT.Collection{SidesNFT.CollectionPublic}>(
                        SidesNFT.CollectionPublicPath,
                        target: SidesNFT.CollectionStoragePath
                    )
                }
            }

            execute { 
                SidesNFT.mintLevel0(flowVault: <-self.vault, num: num, address: self.address)
            }
        }
      `,
      args: (arg, t) => [
        arg(numLevel0ToMint, t.UInt32),
        arg((parseFloat(numLevel0ToMint) * 1.0).toFixed(1), t.UFix64)
      ],
      payer: fcl.authz,
      proposer: fcl.authz,
      authorizations: [fcl.authz],
      limit: 1000
    })
    setTxId(transactionId);
    fcl.tx(transactionId).subscribe(updateTx)
  }


  return (
    <div>
      {transactionInProgress
        ? <Transaction transactionStatus={transactionStatus} transactionError={transactionError} txId={txId} hideTx={hideTx} />
        : <span></span>
      }
      <div className="grid">
        <div id="left-panel">   
          <div id="container">
            <h5>Collection Statistics</h5>
            <p>Latest mint: {(stats && stats[1] > 0)? ("#" + (stats[1] - 1)) : "NA"}</p>
            <img id="lastMint" src={stats? "/" + stats[4] + ".png": ""} className="center"/>
            <table>
              <tbody>
                {stats? Object.entries(stats[0]).map(([key, value]) => (  
                  <tr key={key+3}>
                    <td>Level {key} Supply</td>
                    <td>{value}</td>
                  </tr>
                  )) : <tr key="3"></tr>}
                <tr key="0">
                  <td>Total Level 0 Minted</td>
                  <td>{stats? stats[2] + "/1000" : "NA"}</td>
                </tr>
                <tr key="1">
                  <td>Level 0 Mint Date Limit</td>
                  <td>March 15th</td>
                </tr>
                <tr key="2">
                  <td>Maximum Achievable Level</td>
                  <td>{stats? stats[3] : "NA"}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
        <div id="right-panel">
          <div className="center">
            {user?.loggedIn?
              <div>
                <h5>My Collection</h5>
                <table>
                  <tbody>
                    {myIds && myLevels && myImgs? Object.entries(myIds).map(([key, value]) => (  
                      <tr key={key}>                            
                        <td>Id #{value}</td>
                        <td>Level {myLevels[key]}</td>
                        <td><a alt={value[0]} href={"/" + myImgs[key] + ".png"} target="_blank" rel="noreferrer"><img src={"/" + myImgs[key] + ".png"} className="collection-img"/></a></td>                          
                      </tr>
                    )) : <tr key="0"></tr>}
                  </tbody>
                </table>
                <div style={{display: 'flex', alignItems:'center'}}>
                    <button style={{marginRight: '10px'}} onClick={mintLevel0}>MINT</button>
                    <input style={{width: '80px', marginBottom:0}} type="number" step="1" min="1" max="10" placeholder="1" onChange={(e) => setNumLevel0ToMint(e.target.value)}/>
                    <p style={{marginLeft:'10px', marginBottom:'0'}}>Level-0 NFTs for {numLevel0ToMint? numLevel0ToMint : 0} Flow</p>       
                </div>
                <div style={{display: 'flex', alignItems:'center'}}>
                    <button style={{marginRight: '10px'}} onClick={upgradeNFT}>UPGRADE</button>                  
                    <p style={{marginRight: '10px', marginBottom:'0'}}>to Level</p>
                    <input style={{width: '80px', marginBottom:0}} type="number" step="1" min="1" max="5" placeholder="1" onChange={(e) => setUpgradeToLevel(e.target.value)}/>
                    <p style={{marginLeft: '10px', marginBottom:'0'}}>(burn 3 Level-{upgradeToLevel? upgradeToLevel-1 : 0})</p>
                </div>
                <div style={{display: 'flex', alignItems:'center'}}>
                    <button style={{marginRight: '10px'}} onClick={downgradeNFT}>DOWNGRADE</button>                  
                    <p style={{marginRight: '10px', marginBottom:'0'}}>one Level</p>
                    <input style={{width: '80px', marginBottom:0}} type="number" step="1" min="1" max="5" placeholder="1" onChange={(e) => setDowngradeFromLevel(e.target.value)}/>
                    <p style={{marginLeft: '10px', marginBottom:'0'}}>to 2 Level-{downgradeFromLevel? downgradeFromLevel-1 : 0}</p>
                </div>
                <div style={{marginTop: '50px'}} className="infoList">Address: {user.addr}</div>
                <div className="infoList" style={{display: 'flex', alignItems:'center'}}>
                  Flow balance: {flowBalance ?? "ND"}
                </div>
                <div className="infoList" style={{display: 'flex', alignItems:'center'}}>
                  Level-0 NFTs left to mint: {level0LeftToMint}
                </div>
                <button style={{marginTop: '40px'}} onClick={logOut}>LOGOUT</button>
              </div>
            : <div>
                <button onClick={fcl.authenticate}>CONNECT</button>
              </div>
            }
          </div>
        </div>
      </div>
    </div>
  )
}

export default App;
