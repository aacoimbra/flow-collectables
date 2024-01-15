import "BBCollectables"
import "NonFungibleToken"
import "MetadataViews"

// This transaction sets up an account to use Viralat
// by storing an empty moment collection and creating
// a public capability for it
transaction {

    prepare(acct: AuthAccount) {

        // First, check to see if a moment collection already exists
        if acct.borrow<&BBCollectables.Collection>(from: BBCollectables.NftCollectionStoragePath) == nil {

            // create a new Lat Collection
            let collection <- BBCollectables.createEmptyCollection() as! @BBCollectables.Collection

            // Put the new Collection in storage
            acct.save(<-collection, to: BBCollectables.NftCollectionStoragePath)

            // create a public capability for the collection
            // acct.link<&{Lat.LatNftCollectionPublic}>(/public/LatNftCollection, target: /storage/LatNftCollection)
            acct.link<&BBCollectables.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(BBCollectables.NftCollectionPublicPath, target: BBCollectables.NftCollectionStoragePath)
        }

    }
}