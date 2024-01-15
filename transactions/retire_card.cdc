import "BBCollectables"

transaction(packID: UInt32, cardID: UInt32) {

    let adminRef: &BBCollectables.Admin

    prepare(acct: AuthAccount) {

        self.adminRef = acct.borrow<&BBCollectables.Admin>(from: BBCollectables.AdminStoragePath)!
    }

    execute {

        let packRef = self.adminRef.borrowPack(packID: packID)
        packRef.retireCard(cardID: cardID)
        
    }
}