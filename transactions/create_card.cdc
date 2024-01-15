import "BBCollectables"

transaction(metadata: {String: String}) {

    // Local variable for the Admin object
    let adminRef: &BBCollectables.Admin
    let currCardID: UInt32

    prepare(acct: AuthAccount) {

        // borrow a reference to the admin resource
        self.currCardID = BBCollectables.nextCardID;
        self.adminRef = acct.borrow<&BBCollectables.Admin>(from: BBCollectables.AdminStoragePath)
            ?? panic("No admin resource in storage.")
    }

    execute {

        // Create a play with the specified metadata
        self.adminRef.createCard(metadata: metadata)
    }

    post {
        
        BBCollectables.getCardMetaData(cardID: self.currCardID) != nil:
            "Card does not exist."
    }
}