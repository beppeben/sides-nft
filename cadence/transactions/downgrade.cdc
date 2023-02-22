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
 