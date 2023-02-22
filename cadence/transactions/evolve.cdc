import SidesNFT from 0xSIDESNFTCONTRACTADDRESS

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
 