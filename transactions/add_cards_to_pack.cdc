import "BBCollectables"

transaction(packID: UInt32, cardIDs: [UInt32], mintCaps: [UInt32]) {

    let adminRef: &BBCollectables.Admin

    prepare(acct: AuthAccount) {

        // borrow a reference to the Admin resource in storage
        self.adminRef = acct.borrow<&BBCollectables.Admin>(from: BBCollectables.AdminStoragePath)
            ?? panic("Could not borrow a reference to the Admin resource")
    }

    execute {
        
        let packRef = self.adminRef.borrowPack(packID: packID)

        packRef.addCards(cardIDs: cardIDs, mintCaps: mintCaps)
    }
}