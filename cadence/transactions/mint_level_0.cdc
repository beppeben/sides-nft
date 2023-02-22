import SidesNFT from 0xSIDESNFTCONTRACTADDRESS
import FlowToken from 0xFLOWTOKEN

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
 