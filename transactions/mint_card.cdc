import "BBCollectables"
import "NonFungibleToken"
import "MetadataViews"

transaction(packID: UInt32, cardID: UInt32) {
    // local variable for the admin reference
    let adminRef: &BBCollectables.Admin
    let receiverRef: &AnyResource{NonFungibleToken.CollectionPublic}

    prepare(admin: AuthAccount, user: AuthAccount) {
        // borrow a reference to the Admin resource in storage
        self.adminRef = admin.borrow<&BBCollectables.Admin>(from: BBCollectables.AdminStoragePath)!

        if user.borrow<&BBCollectables.Collection>(from: BBCollectables.NftCollectionStoragePath) == nil {
            
            let collection  <- BBCollectables.createEmptyCollection()

            user.save(<- collection, to: BBCollectables.NftCollectionStoragePath)

            user.link<&{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(BBCollectables.NftCollectionPublicPath, target: BBCollectables.NftCollectionStoragePath)
        }

        self.receiverRef = user.getCapability(BBCollectables.NftCollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>()!
    }

    execute {

        let packRef: &BBCollectables.Pack = self.adminRef.borrowPack(packID: packID)

        let mintedCard: @BBCollectables.NFT <-! packRef.mintBBNft(cardID: cardID)

        self.receiverRef.deposit(token: <- mintedCard )
    }
}