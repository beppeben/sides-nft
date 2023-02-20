// Implementation of the SidesNFT contract
// SidesNFT is an experimentation around the concept of adaptive NFT collections
// i.e. collections whose supply and rarity can evolve based on users' preferences and interactions

import NonFungibleToken from 0x631e88ae7f1d7c20
import MetadataViews from 0x631e88ae7f1d7c20

import FungibleToken from 0x9a0766d93b6608b7
import FlowToken from 0x7e60df042a9c0868

pub contract SidesNFT: NonFungibleToken {

    // PATHS
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Total number of NFTs in circulation
    pub var totalSupply: UInt64

    // COLLECTION CONFIGURATIONS
    pub let configs: CollectionConfigs

    // BOOKKEEPING
    pub let stats: Stats

    // MINTER
    // Resource used to mint new NFTs
    access(contract) let minter: @NFTMinter


    // EVENTS
    // Event emitted when the contract is initialized
    pub event ContractInitialized()

    // Event emitted when users withdraw from their NFT collection
    pub event Withdraw(id: UInt64, from: Address?)

    // Event emitted when users deposit into their NFT collection
    pub event Deposit(id: UInt64, to: Address?)

    // Event emitted when a new NFT is minted
    // Either at the genesis level-0 or with a higher level by burning existing NFTs
    pub event Minted(id: UInt64, level: UInt32)

    // Event emitted when an NFT is burned for minting a higher or lower level one
    pub event Burned(id: UInt64, level: UInt32)


    // STRUCTS
    // This struct contains all the configurations of this collection
    pub struct CollectionConfigs {
        // Level 0 NFTs will only be mintable before this date
        pub let level0DateLimit: UFix64

        // Price (in Flow) of Level 0 NFTs
        pub let level0Price: UFix64

        // Maximum number of Level 0 NFTs mintable per wallet
        pub let maxLevel0mintPerWallet: UInt32

        // Maximum supply of Level 0 NFTs
        pub let maxLevel0Supply: UInt64

        // You need to burn numEvolve Level n NFTs to get 1 Level (n+1) NFT
        pub let numEvolve: UInt32

        // Map of supported levels to the (IPFS) images to be randomly assigned to newly minted NFTs
        access(contract) let levelsToImgs: {UInt32: [String]}

        // Maximum rarity level deduced from the levelsToImgs configuration map
        pub let maxSupportedLevel: UInt32

        // Specifies a penalty for downgrading to NFTs of lower level
        // 1 NFT of level (n+1) will be downgraded into (numEvolve - downgradePenalty) NFTs of Level n
        // If nil, downgrading is not supported
        pub let downgradePenalty: UInt32?

        // Address used for receiving tokens
        pub let tokenAddress: Address

        init(level0DateLimit: UFix64, level0Price: UFix64, maxLevel0mintPerWallet: UInt32, maxLevel0Supply: UInt64, numEvolve: UInt32, levelsToImgs: {UInt32: [String]}, downgradePenalty: UInt32?, tokenAddress: Address) {
            self.level0DateLimit = level0DateLimit
            self.level0Price = level0Price
            self.maxLevel0mintPerWallet = maxLevel0mintPerWallet
            self.maxLevel0Supply = maxLevel0Supply
            self.numEvolve = numEvolve
            self.levelsToImgs = levelsToImgs
            self.downgradePenalty = downgradePenalty
            self.tokenAddress = tokenAddress

            var maxSupportedLevel = UInt32(0)
            for level in self.levelsToImgs.keys {
                if level > maxSupportedLevel {
                    maxSupportedLevel = level
                }
            }
            self.maxSupportedLevel = maxSupportedLevel
        }
    }

    // This struct helps keeping track of the collection ongoing statistics and updating them
    pub struct Stats {
        // Total number of NFTs in circulation by level
        access(contract) var totalSupplyByLevel: {UInt32: UInt64}

        // Total number of NFTs ever minted (including those that have been burnt and downgrades)
        pub var totalGrossSupply: UInt64

        // Total number of Level-0 NFTs ever minted directly (not including downgrades)
        pub var totalLevel0Minted: UInt64

        // Maximum rarity level attainable based on the number of minted Level 0 NFTs, and the maxSupportedLevel
        pub var maxMintableLevel: UInt32

        // Last image that has been minted (can be shown on the website)
        pub var lastMintedImage: String

        // Integer logarithm
        pub fun IntegerLog(base: UInt32, num: UInt64): UInt32 {
            var res = 0
            var test = base
            while UInt64(test) <= num {
                test = test * base
                res = res + 1
            }
            return UInt32(res)
        }

        // Update stats after upgrading to a higher level NFT
        access(contract) fun updateAfterMintUp(currLevel: Int, fromLength: Int) {
            let level = UInt32(currLevel + Int(1))

            // increase gross total supply by 1
            self.totalGrossSupply = self.totalGrossSupply + 1
            
            // decrease total supply by the number of burnt NFTs, increase by 1 at the following level
            SidesNFT.totalSupply = SidesNFT.totalSupply + 1 - UInt64(fromLength)
            if currLevel >= 0 {
                self.totalSupplyByLevel[UInt32(currLevel)] = self.totalSupplyByLevel[UInt32(currLevel)]! - UInt64(fromLength)
            }
            if self.totalSupplyByLevel[level] == nil {
                self.totalSupplyByLevel[level] = 1
            } else {
                self.totalSupplyByLevel[level] = self.totalSupplyByLevel[level]! + UInt64(1)
            }

            if level == 0 {
                // when minting Level 0 NFTs, update the maximum reachable rarity level
                self.totalLevel0Minted = self.totalLevel0Minted + 1
                self.maxMintableLevel = self.IntegerLog(base: SidesNFT.configs.numEvolve, num: self.totalLevel0Minted)
                if self.maxMintableLevel > SidesNFT.configs.maxSupportedLevel {
                   self.maxMintableLevel = SidesNFT.configs.maxSupportedLevel
                }
            }
        }

        // Update stats after downgrading to lower level NFTs
        access(contract) fun updateAfterMintDown(newLevel: UInt32) {
            let diff = UInt64(SidesNFT.configs.numEvolve - SidesNFT.configs.downgradePenalty!)
            self.totalGrossSupply = self.totalGrossSupply + diff
            SidesNFT.totalSupply = SidesNFT.totalSupply + diff - 1
            self.totalSupplyByLevel[newLevel] = self.totalSupplyByLevel[newLevel]! + diff
            self.totalSupplyByLevel[newLevel+1] = self.totalSupplyByLevel[newLevel+1]! - 1
        }

        // Update last minted image
        access(contract) fun setLastMintedImage(image: String) {
            self.lastMintedImage = image
        }

        init() {      
            self.totalSupplyByLevel = {}
            self.totalGrossSupply = 0
            self.totalLevel0Minted = 0
            self.maxMintableLevel = 0
            self.lastMintedImage = ""
        }
    }


    // RESOURCES
    // Resource that the contract owns to create new NFTs. Contains the minting/evolving logic
    pub resource NFTMinter {

        // Logic to select the image of the newly evolved NFT
        // The current implementation simply randomizes using a seed based on the ids of the burnt NFTs
        // Alternative implementations could insert here a different logic to possibly make the new NFT
        // depend on the characteristics of the burned NFTs that have been used to mint it
        pub fun selectImageForMintUp(fromNFTs: &[NFT], level: UInt32, id: UInt64): String {
            let len = fromNFTs.length
            var i = 0
            var seed = UInt64(0)
            while i < len {
                seed = seed + fromNFTs[i].id
                i = i + 1
            }
            let img = SidesNFT.configs.levelsToImgs[level]![(id + seed) % UInt64(SidesNFT.configs.levelsToImgs[level]!.length)]
            return img
        }

        // Logic to select the image of the newly downgraded NFT
        pub fun selectImageForMintDown(fromNFT: &NFT, level: UInt32, id: UInt64): String {
            let img = SidesNFT.configs.levelsToImgs[level]![id % UInt64(SidesNFT.configs.levelsToImgs[level]!.length)]
            return img
        }
   

        // Mints a new NFT or evolves from existing ones
        pub fun mintUp(fromNFTs: @[NFT]) : @NFT {
            
            let len = fromNFTs.length
            let currLevel = Int(len == 0? -1 : fromNFTs[0].level)
                        
            // check validity of date
            if len == 0 && getCurrentBlock().timestamp > SidesNFT.configs.level0DateLimit {
                panic("Cannot mint a Level 0 after the date limit")
            }
            // and that the number of provided NFTs matches with the required one for upgrading
            if len > 0 && UInt32(len) != SidesNFT.configs.numEvolve {
                panic("Number of NFTs provided doesn't match the required number for evolving into a new one.")
            }
            var i = 0            
            while i < len {
                if fromNFTs[i].level != UInt32(currLevel) {
                    panic("You can only burn NFTs of the same level")
                }
                // emit burn events for each input NFTs
                emit Burned(id: fromNFTs[i].id, level: fromNFTs[i].level)
                i = i + 1
            }

            // check rarity and supply availability
            let level = UInt32(currLevel + Int(1))
            if level > SidesNFT.configs.maxSupportedLevel {
                panic("You've already reached the maximum supported rarity, cannot upgrade further.")
            }
            if level == 0 && SidesNFT.stats.totalLevel0Minted >= SidesNFT.configs.maxLevel0Supply {
                panic("Exceeded maximum available supply.")
            }
            // create a new NFT
            let id = SidesNFT.stats.totalGrossSupply
            let thumbnail = self.selectImageForMintUp(fromNFTs: &fromNFTs as &[NFT], level: level, id: id)
            var newNFT <- create NFT(initID: id, level: level, thumbnail: thumbnail)
            
            // update collection stats
            SidesNFT.stats.updateAfterMintUp(currLevel: currLevel, fromLength: len)

            // destroy the provided NFTs
            destroy fromNFTs  

            return <-newNFT
        }

        // Downgrades an NFT into a set of NFTs of the preceding level
        pub fun mintDown(fromNFT: @NFT) : @[NFT] {
            if SidesNFT.configs.downgradePenalty == nil {
                panic("The collection doesn't support downgrading an NFT.")
            }
            if fromNFT.level == 0 {
                panic ("Cannot downgrade an NFT of Level 0")
            }
            let newLevel = fromNFT.level - 1

            var i = 0
            var res: @[NFT] <- []
            while UInt32(i) < SidesNFT.configs.numEvolve - SidesNFT.configs.downgradePenalty! {
                // create a new NFT
                let id = SidesNFT.stats.totalGrossSupply
                let thumbnail = self.selectImageForMintDown(fromNFT: &fromNFT as &NFT, level: newLevel, id: id)
                var newNFT <- create NFT(initID: id, level: newLevel, thumbnail: thumbnail)
                res.append(<-newNFT)
                i = i + 1
            }

            // update collection stats
            SidesNFT.stats.updateAfterMintDown(newLevel: newLevel)

            // burn original NFT
            emit Burned(id: fromNFT.id, level: fromNFT.level)
            destroy fromNFT
            
            return <-res
        }
    }

    // Standard NFT resource
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let level: UInt32


        init(initID: UInt64, level: UInt32, thumbnail: String) {
            self.id = initID
            self.name = "SidesNFT #".concat(initID.toString())
            self.description = "SidesNFT of level ".concat(level.toString())
            self.thumbnail = thumbnail
            self.level = level

            SidesNFT.stats.setLastMintedImage(image: thumbnail)
            emit Minted(id: initID, level: level)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: "URL/".concat(self.thumbnail).concat(".png")
                        )
                    )

                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: SidesNFT.CollectionStoragePath,
                        publicPath: SidesNFT.CollectionPublicPath,
                        providerPath: /private/SidesNFTCollectionProvider,
                        publicCollection: Type<&SidesNFT.Collection{SidesNFT.CollectionPublic}>(),
                        publicLinkedType: Type<&SidesNFT.Collection{SidesNFT.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&SidesNFT.Collection{SidesNFT.CollectionPublic,NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-SidesNFT.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.Traits>():
                    let rarityDesc = "Level ".concat(self.level.toString())
                    let levelRarity = MetadataViews.Rarity(score: UFix64(self.level), max: UFix64(SidesNFT.stats.maxMintableLevel), description: rarityDesc)

                    let levelTrait = MetadataViews.Trait(name: "Level", value: self.level.toString(), displayType: "String", rarity: levelRarity)

                    let traits = MetadataViews.Traits([levelTrait])

                    return traits
            }

            return nil
        }
    }

    // Standard collection public interface
    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowSidesNFT(id: UInt64): &SidesNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow SidesNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Standard collection resource
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // Removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @SidesNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // Returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // Gets a reference to an NFT in the collection as a SidesNFT,
        // exposing all of its fields.
        pub fun borrowSidesNFT(id: UInt64): &SidesNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &SidesNFT.NFT?
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let sidesNFT = nft as! &SidesNFT.NFT
            return sidesNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }


    // PUBLIC APIs //
    // Create an empty NFT collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Mint Level 0 NFTs
    pub fun mintLevel0(flowVault: @FlowToken.Vault, num: UInt32, address: Address) {
        if num > self.configs.maxLevel0mintPerWallet {
            panic("You're not allowed to mint more than ".concat(self.configs.maxLevel0mintPerWallet.toString()))
        }
        if flowVault.balance != UFix64(num) * self.configs.level0Price {
            panic("Invalid token balance.")
        }

        // deposit Flow
        let flowRec = getAccount(self.configs.tokenAddress).getCapability(/public/flowTokenReceiver) 
                        .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
                        ?? panic("Could not borrow a reference to the Flow receiver")
        flowRec.deposit(from: <- flowVault)

        // mint and send NFTs
        let NFTrec = getAccount(address).getCapability(SidesNFT.CollectionPublicPath)
                    .borrow<&{SidesNFT.CollectionPublic}>()
                    ?? panic("Could not get receiver reference to the NFT Collection")

        var counter = UInt32(0)
        while counter < num {
            let nft <- self.minter.mintUp(fromNFTs: <-[])
            NFTrec.deposit(token: <-nft)
            counter = counter + UInt32(1)
        }
    }

    // Evolve (and burn) existing NFTs into a higher level one
    pub fun evolveNFTs(fromNFTs: @[NFT], address: Address) {
        if fromNFTs.length == 0 {
            panic("Not enough assets to burn for the evolution.")
        }
        // mint and send NFTs
        let nft <- self.minter.mintUp(fromNFTs: <-fromNFTs)
        let NFTrec = getAccount(address).getCapability(SidesNFT.CollectionPublicPath)
                    .borrow<&{SidesNFT.CollectionPublic}>()
                    ?? panic("Could not get receiver reference to the NFT Collection")
        NFTrec.deposit(token: <-nft)
    }

    // Downgrade NFT into NFTs of the previous level
    pub fun downgradeNFTs(fromNFT: @NFT, address: Address) {
        let nfts <- self.minter.mintDown(fromNFT: <- fromNFT)

        let NFTrec = getAccount(address).getCapability(SidesNFT.CollectionPublicPath)
                    .borrow<&{SidesNFT.CollectionPublic}>()
                    ?? panic("Could not get receiver reference to the NFT Collection")

        var a = 0
        let len = nfts.length
        while a < len {
            let nft <- nfts.removeFirst()!
            NFTrec.deposit(token: <-nft)
            a = a + 1
        }
        destroy nfts    // the array is empty at this point
    }

    // INITIALIZATION
    init() {
        // Set named paths
        self.CollectionStoragePath = /storage/SidesNFTCollection1
        self.CollectionPublicPath = /public/SidesNFTCollection1

        self.totalSupply = 0        

        // Initialize collection configs
        let level0DateLimit = 1678055744.0  // corresponds to March 5th 2023
        let level0Price = 1.0
        let maxLevel0mintPerWallet = UInt32(5)
        let maxLevel0Supply = UInt64(100)
        let numEvolve = UInt32(3)
        let tokenAddress = self.account.address
        // list of images for each level, to be assigned randomly on mint
        // just repeat the same image name many times if you want it to be relatively more common
        let levelsToImgs = {
            UInt32(0): ["img_0_0", "img_0_1", "img_0_2"], 
            UInt32(1): ["img_1_0", "img_1_1", "img_1_2"], 
            UInt32(2): ["img_2_0", "img_2_1", "img_2_2"],
            UInt32(3): ["img_3_0", "img_3_1", "img_3_2"], 
            UInt32(4): ["img_4_0", "img_4_1", "img_4_2"],
            UInt32(5): ["img_5_0", "img_5_1", "img_5_2"]}
        let downgradePenalty = UInt32(1)

        self.configs = CollectionConfigs(level0DateLimit: level0DateLimit, level0Price: level0Price, maxLevel0mintPerWallet: maxLevel0mintPerWallet, maxLevel0Supply: maxLevel0Supply, numEvolve: numEvolve, levelsToImgs: levelsToImgs, downgradePenalty: downgradePenalty, tokenAddress: tokenAddress)

        // Initialize minter and stats
        self.minter <- create NFTMinter()
        self.stats = Stats()
        
        emit ContractInitialized()
    }
}