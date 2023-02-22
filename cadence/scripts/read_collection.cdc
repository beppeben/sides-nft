import NonFungibleToken from 0xNONFUNGIBLETOKEN
import SidesNFT from 0xSIDESNFTCONTRACTADDRESS

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