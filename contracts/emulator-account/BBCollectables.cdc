// import NonFungibleToken from 0x631e88ae7f1d7c20
// import MetadataViews from 0x631e88ae7f1d7c20
// import FungibleToken from 0x9a0766d93b6608b7
// import PRNG from 0x2bf5575475144be3

import "NonFungibleToken"
import "MetadataViews"
import "FungibleToken"
// import "PRNG"

pub contract BBCollectables: NonFungibleToken {

    // pub let network: String

    pub event ContractInitialized()

    pub event CardCreated(cardID: UInt32, metadata: {String:String})
    pub event PackCreated(packID: UInt32)

    pub event CardAddedToPack(packID: UInt32, cardID: UInt32)
    pub event CardRetiredFromPack(packID: UInt32, cardID: UInt32, numCards: UInt32)
    pub event CardUnretiredFromPack(packID: UInt32, cardID: UInt32, numCards: UInt32)

    pub event PackLocked(packID: UInt32)
    pub event PackUnlocked(packID: UInt32)

    pub event BlockPackMint(packID: UInt32)

   
    pub event TicketMinted(packID: UInt32, serialNumber: UInt32) 
    pub event TicketSpent(id: UInt64, packID: UInt32, serialNumber: UInt32, content: [UInt32])
    pub event TicketDestroyed(id: UInt64)

    pub event BBNftMinted(BBNftID: UInt64, cardID: UInt32, packID: UInt32, serialNumber: UInt32)
    pub event BBNftDestroyed(id: UInt64)


    pub event Withdraw(id: UInt64, from: Address?)

    pub event Deposit(id: UInt64, to: Address?)

    pub let NftCollectionStoragePath: StoragePath
    pub let NftCollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    pub var cardDatas: {UInt32: Card}
    access(self) var packDatas: {UInt32: PackData}
    pub var packs: @{UInt32: Pack}

    pub var nextCardID: UInt32
    pub var nextPackID: UInt32

    pub var totalSupply: UInt64


    pub struct Card {

        pub let cardID: UInt32

        // pub let categories: [String]

        pub let metadata: {String: String}

        init(metadata: {String: String}) {
            pre {
                metadata.length != 0: "New Card metadata cannot be empty"
            }
            self.cardID = BBCollectables.nextCardID
            // self.categories = categories
            self.metadata = metadata
        }
    }

    pub struct PackData {

        pub let packID: UInt32

        pub let name: String

        pub let rarityDistribution: {String: UInt256}

        init(name: String, rarityDistribution: {String: UInt256}) {
            pre {
                name.length > 0: "New Pack name cannot be empty"
            }
            self.packID = BBCollectables.nextPackID
            self.name = name
            self.rarityDistribution = rarityDistribution
        }
    }

    pub resource Pack {

        pub let name: String

        pub let packID: UInt32

        access(contract) var rarityDistribution: {String: UInt256}

        access(contract) var cards: [UInt32]

        access(contract) var retired: {UInt32: Bool}

        pub var locked: Bool

        access(contract) var ticketsMinted: UInt32

        access(contract) var ticketsSpent: UInt32

        access(contract) var ticketsDestroyed: UInt32

        access(contract) var mintCapPerCard: {UInt32: UInt32}

        access(contract) var numberMintedPerCard: {UInt32: UInt32}

        access(contract) var numberDestroyedPerCard: {UInt32: UInt32}

        pub var cardsAvailableByRarity: {String: [UInt32]}

        init(name: String, rarityDistribution: {String: UInt256}) {
            self.name = name
            self.packID = BBCollectables.nextPackID
            self.rarityDistribution = rarityDistribution
            self.cards = []
            self.retired = {}
            self.locked = false
            self.ticketsMinted = 0
            self.ticketsSpent = 0
            self.ticketsDestroyed = 0
            self.mintCapPerCard = {}
            self.numberMintedPerCard = {}
            self.numberDestroyedPerCard = {}
            self.cardsAvailableByRarity = {}

            for rarity in rarityDistribution.keys {
                self.cardsAvailableByRarity[rarity] = []
            }

            BBCollectables.packDatas[self.packID] = PackData(name: name, rarityDistribution: rarityDistribution)
        }

        pub fun addCard(cardID: UInt32, mintCap: UInt32) {

            pre {
                BBCollectables.cardDatas[cardID] != nil: "Cannot add the Card to Pack: Card doesn't exist."
                !self.locked: "Cannot add the Card to the Pack after the Pack has been locked."
                self.numberMintedPerCard[cardID] == nil: "The Card has already beed added to the Pack."
                self.rarityDistribution[BBCollectables.getCardMetaDataByField(cardID: cardID, field: "rarity")!] != nil: "The Card rarity not included in pack."
                mintCap >= 0: "'maxCount' parameter must be 0 or higher."
            }


            self.cards.append(cardID)

            self.retired[cardID] = false

            self.mintCapPerCard[cardID] = mintCap

            self.numberMintedPerCard[cardID] = 0

            self.numberDestroyedPerCard[cardID] = 0
            
            self.cardsAvailableByRarity[BBCollectables.getCardMetaDataByField(cardID: cardID, field: "rarity")!]!.append(cardID)

            emit CardAddedToPack(packID: self.packID, cardID: cardID)
        }

        pub fun addCards(cardIDs: [UInt32], mintCaps: [UInt32]) {
            
            var i = 0
            while i < cardIDs.length {
                self.addCard(cardID: cardIDs[i], mintCap: mintCaps[i])
                i = i + 1
            }
                
        }
        

        pub fun retireCard(cardID: UInt32) {
            pre {
                self.retired[cardID] != nil: "Cannot retire the Card: Card doesn't exist in this Pack!"
                self.retired[cardID] == false: "Cannot retire the Card: Card already retired!"
                !self.locked: "Cannot retire card: This Pack is locked."
            }

            let cardRarity = BBCollectables.getCardMetaDataByField(cardID: cardID, field: "rarity")!

            var index: UInt16 = 0
            for value in self.cardsAvailableByRarity[cardRarity]! {
                if value == cardID {
                self.cardsAvailableByRarity[cardRarity]!.remove(at: index)
                }
                index = index + 1
            }
            

            if !self.retired[cardID]! {
                self.retired[cardID] = true

                emit CardRetiredFromPack(packID: self.packID, cardID: cardID, numCards: self.numberMintedPerCard[cardID]!)
            }
        }

        pub fun unretireCard(cardID: UInt32) {
            pre {
                self.retired[cardID] != nil: "Cannot unretire the Card: Card doesn't exist in this Pack!"
                self.retired[cardID] == true: "Cannot unretire the Card: Card must be retired!"
                self.numberMintedPerCard[cardID]! < self.mintCapPerCard[cardID]! || self.mintCapPerCard[cardID]! == 0: "Cannot unretire the Card: Card has reached it's maximum mint cap!"
                !self.locked: "Cannot retire card: This Pack is locked."
            }

            let cardRarity = BBCollectables.getCardMetaDataByField(cardID: cardID, field: "rarity")!

            self.cardsAvailableByRarity[cardRarity]!.insert(at: self.cardsAvailableByRarity[cardRarity]!.length - 1, cardID)

            if self.retired[cardID]! {
                self.retired[cardID] = false

                emit CardUnretiredFromPack(packID: self.packID, cardID: cardID, numCards: self.numberMintedPerCard[cardID]!)
            }
        }

        pub fun retireAll() {
            for card in self.cards {
                self.retireCard(cardID: card)
            }
        }

        pub fun lock() {
            if !self.locked {
                self.locked = true
                emit PackLocked(packID: self.packID)
            }
        }

        pub fun unlock() {
            if self.locked {
                self.locked = false
                emit PackUnlocked(packID: self.packID)
            }
        }

        pub fun spentTicketCount() {
            self.ticketsSpent = self.ticketsSpent +1
        }

        pub fun destroyedTicketCount() {
            self.ticketsDestroyed = self.ticketsDestroyed +1
        }


        pub fun mintBBNft(cardID: UInt32): @NFT {
            pre {
                self.retired[cardID] != nil: "Cannot mint the Card: This Card doesn't exist."
                !self.retired[cardID]!: "Cannot mint the Card from this Pack: This Card has been retired."
                self.numberMintedPerCard[cardID]! < self.mintCapPerCard[cardID]! || self.mintCapPerCard[cardID]! == 0: "Card has reached the maximum mint cap."
            }

            let numInCard = self.numberMintedPerCard[cardID]!

            let newBBNft: @NFT <- create NFT(cardID: cardID,
                                              packID: self.packID,
                                              timestamp: getCurrentBlock().timestamp,
                                              packIndex: UInt32(self.cards.firstIndex(of: cardID)!),
                                              serialNumber: numInCard +1
                                              )
            
            self.numberMintedPerCard[cardID] = numInCard +1

            if self.numberMintedPerCard[cardID]! >= self.mintCapPerCard[cardID]! && self.mintCapPerCard[cardID]! > 0 {
                self.retireCard(cardID: cardID)
            }

            return <-newBBNft
        }

        pub fun destroyBBNft(cardID: UInt32) {
            self.numberDestroyedPerCard[cardID] = self.numberDestroyedPerCard[cardID]! +1
        }

        pub fun batchMintBBNft(cardID: UInt32, quantity: UInt64): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintBBNft(cardID: cardID))
                i = i +1
            }

            return <-newCollection
        }

        pub fun getRarityDistribution(): {String: UInt256} {
            return self.rarityDistribution
        }

        pub fun getCards(): [UInt32] {
            return self.cards
        }

        pub fun getRetired(): {UInt32: Bool} {
            return self.retired
        }

        pub fun getNumMintedPerCard(): {UInt32: UInt32} {
            return self.numberMintedPerCard
        }
    }

    pub struct QueryPackData {
        pub let packID: UInt32
        pub let name: String
        pub var locked: Bool
        access(self) var rarityDistribution: {String: UInt256}
        access(self) var cards: [UInt32]
        access(self) var retired: {UInt32: Bool}
        access(self) var cardsAvailableByRarity: {String: [UInt32]}
        access(contract) var ticketsMinted: UInt32
        access(contract) var ticketsSpent: UInt32
        access(contract) var ticketsDestroyed: UInt32
        access(self) var mintCapPerCard: {UInt32: UInt32}
        access(self) var numberMintedPerCard: {UInt32: UInt32}
        access(self) var numberDestroyedPerCard: {UInt32: UInt32}
        

        init(packID: UInt32) {
            pre {
                BBCollectables.packs[packID] != nil: "The Pack with the provided ID does not exist"
            }

            let pack= (&BBCollectables.packs[packID] as &Pack?)!
            let packData = BBCollectables.packDatas[packID]!

            self.packID = packID
            self.name = packData.name
            self.locked = pack.locked
            self.rarityDistribution = pack.rarityDistribution
            self.cards = pack.cards
            self.retired = pack.retired
            self.cardsAvailableByRarity = pack.cardsAvailableByRarity
            self.ticketsMinted = pack.ticketsMinted
            self.ticketsSpent = pack.ticketsSpent
            self.ticketsDestroyed = pack.ticketsDestroyed
            self.mintCapPerCard = pack.mintCapPerCard
            self.numberMintedPerCard = pack.numberMintedPerCard
            self.numberDestroyedPerCard = pack.numberDestroyedPerCard
        }

        pub fun getRarityDistribution(): {String: UInt256} {
            return self.rarityDistribution
        }

        pub fun getCards(): [UInt32] {
            return self.cards
        }

        pub fun getRetired(): {UInt32: Bool} {
            return self.retired
        }

        pub fun getcardsAvailableByRarity(): {String: [UInt32]} {
            return self.cardsAvailableByRarity
        }

        pub fun getTicketsMinted(): UInt32 {
            return self.ticketsMinted
        }

        pub fun getTicketsSpent(): UInt32 {
            return self.ticketsSpent
        }

        pub fun getNumberMintedPerCard(): {UInt32: UInt32} {
            return self.numberMintedPerCard
        }

        pub fun getNumberDestroyedPerCard(): {UInt32: UInt32} {
            return self.numberDestroyedPerCard
        }
    }

    pub struct BBNftData {

        pub let cardID: UInt32

        pub let packID: UInt32

        pub let timestamp: UFix64

        pub let packIndex: UInt32

        pub let serialNumber: UInt32


        init(cardID: UInt32, packID: UInt32, timestamp: UFix64, packIndex:UInt32, serialNumber: UInt32) {
            self.cardID = cardID
            self.packID = packID
            self.timestamp = timestamp
            self.packIndex = packIndex
            self.serialNumber = serialNumber
        }

    }

    pub struct BBNftMetadataView {

        pub let name : String?
        pub let description: String?
        pub let rarity: String?
        pub let media: String?

        pub let cardID: UInt32?
        pub let packID: UInt32?
        pub let timestamp: UFix64?
        pub let packIndex: UInt32?
        pub let serialNumber: UInt32?

        init(
            name: String?,
            description: String?,
            rarity: String?,
            media: String?,

            cardID: UInt32?,
            packID: UInt32?,
            timestamp: UFix64?,
            packIndex: UInt32?,
            serialNumber: UInt32?,
            
        ) {
            self.name = name
            self.description = description
            self.rarity = rarity
            self.media = media

            self.cardID = cardID
            self.packID = packID
            self.timestamp = timestamp
            self.packIndex = packIndex
            self.serialNumber = serialNumber
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let data: BBNftData

        init(cardID: UInt32, packID: UInt32, timestamp: UFix64, packIndex: UInt32, serialNumber: UInt32) {

            BBCollectables.totalSupply = BBCollectables.totalSupply +1

            self.id = BBCollectables.totalSupply

            self.data = BBNftData(cardID: cardID, packID: packID, timestamp: timestamp, packIndex: packIndex, serialNumber: serialNumber)

            emit BBNftMinted(BBNftID: self.id, cardID: cardID, packID: self.data.packID, serialNumber: self.data.serialNumber)
        }

        destroy() {
            BBCollectables.packs[self.data.packID]?.destroyBBNft(cardID: self.data.cardID)
            emit BBNftDestroyed(id: self.id)
        }

        pub fun name(): String {
            let cardName: String = BBCollectables.getCardMetaDataByField(cardID: self.data.cardID, field: "name") ?? ""
            return cardName
        }

        pub fun description(): String {
            let packName: String = BBCollectables.getPackName(packID: self.data.packID) ?? ""
            let serialNumber: String = self.data.serialNumber.toString()
            return "A series "
                .concat(packName)
                .concat(" BBNft with serial number ")
                .concat(serialNumber)
        }

        pub fun getCardURL(): String {
 
            return "https://media.BBCollectables.bite.blue/".concat("testnet").concat("/cards/").concat(BBCollectables.getCardMetaDataByField(cardID: self.data.cardID, field: "media")!).concat("/carta.png")
            
            // return BBCollectables.getCardMetaDataByField(cardID: self.data.cardID, field: "media")!
        }

        pub fun mapCardData(dict: {String: AnyStruct}) : {String: AnyStruct} {      
            let cardMetadata = BBCollectables.getCardMetaData(cardID: self.data.cardID) ?? {}
            for name in cardMetadata.keys {
                let value = cardMetadata[name] ?? ""
                if value != "" {
                    dict.insert(key: name, value)
                }
            }
            return dict
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<BBNftMetadataView>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Medias>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.description(),
                        thumbnail: MetadataViews.HTTPFile(url: self.getCardURL())
                    )
                case Type<BBNftMetadataView>():
                    return BBNftMetadataView(
                        name: BBCollectables.getCardMetaDataByField(cardID: self.data.cardID, field: "name"),
                        description: BBCollectables.getCardMetaDataByField(cardID: self.data.cardID, field: "cardDescription"),
                        rarity: BBCollectables.getCardMetaDataByField(cardID: self.data.cardID, field: "rarity"),
                        media: self.getCardURL(),
                        
                        cardID: self.data.cardID,
                        packID: self.data.packID,
                        timestamp: self.data.timestamp,
                        packIndex: self.data.packIndex,
                        serialNumber: self.data.serialNumber,
                    )
                    
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(self.getCardURL())

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: /storage/BBNFTCollection,
                        publicPath: /public/BBNFTCollection,
                        providerPath: /private/BBNFTCollection,
                        publicCollection: Type<&BBCollectables.Collection{NonFungibleToken.CollectionPublic}>(),
                        publicLinkedType: Type<&BBCollectables.Collection{NonFungibleToken.Receiver,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&BBCollectables.Collection{NonFungibleToken.Provider,NonFungibleToken.Receiver,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-BBCollectables.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://media.BBCollectables.bite.blue/testnet/branding/BB-banner.svg"
                        ),
                        mediaType: "image/svg"
                    )
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://media.BBCollectables.bite.blue/testnet/branding/BB-logopack-04.svg"
                        ),
                        mediaType: "image/svg"
                    )

                    return MetadataViews.NFTCollectionDisplay(
                        name: "Organiser Collectables Collection",
                        description: "Uma experiência de outro planeta. 🪐",
                        externalURL: MetadataViews.ExternalURL("https://www.bluebite.tech/"),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/richmond_fc/")
                        }
                    )

                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        UInt64(self.data.serialNumber)
                    )

                case Type<MetadataViews.Traits>():
                    // sports radar team id
                    let excludedNames: [String] = ["timestamp"]
                    // non play specific traits
                    let traitDictionary: {String: AnyStruct} = {
                        "packName": BBCollectables.getPackName(packID: self.data.packID)
                    }
                    // add play specific data
                    let fullDictionary = self.mapCardData(dict: traitDictionary)
                    return MetadataViews.dictToTraits(dict: fullDictionary, excludedNames: excludedNames)

                case Type<MetadataViews.Medias>():
                    return MetadataViews.Medias(
                        items: [
                            MetadataViews.Media(
                                file: MetadataViews.HTTPFile(
                                    url: self.getCardURL()
                                ),
                                mediaType: "image/png"
                            )
                        ]
                    )
            }

            return nil
        }
 
        
    }

    pub struct PackTicketData{

        pub let packID: UInt32

        pub let serialNumber: UInt32

        init(packID: UInt32, serialNumber: UInt32) {
            self.packID = packID
            self.serialNumber = serialNumber
        }
    }

    pub resource Admin {

        pub fun createCard( metadata: {String: String}): UInt32 {

            pre {
                metadata.containsKey("rarity") == true: "Metadata missing rarity field"
                metadata.containsKey("name") == true: "Metadata missing name field"
                metadata.containsKey("description") == true: "Metadata missing description field"
                metadata.containsKey("date") == true: "Metadata missing date field"
            }

            for value in BBCollectables.cardDatas.values {
                if value.metadata["name"] == metadata["name"] {
                    return 0
                }
            }

            var newCard = Card( metadata: metadata)

            let newID = newCard.cardID

            BBCollectables.nextCardID = BBCollectables.nextCardID +1

            emit CardCreated(cardID: newCard.cardID, metadata: newCard.metadata)

            BBCollectables.cardDatas[newID] = newCard

            return newID
        }

        pub fun createPack(name: String, rarityDistribution: {String: UInt256}): UInt32 {

            var newPack <- create Pack(name: name, rarityDistribution: rarityDistribution)

            BBCollectables.nextPackID = BBCollectables.nextPackID +1

            let newID = newPack.packID

            emit PackCreated(packID: newPack.packID)

            BBCollectables.packs[newID] <-! newPack

            return newID
        }

        pub fun borrowPack(packID: UInt32): &Pack {
            pre {
                BBCollectables.packs[packID] != nil: "Cannot borrow Pack: The Pack doesn't exist"
            }
            
            return (&BBCollectables.packs[packID] as &Pack?)!
        }

        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection { 

        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {

            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Cannot withdraw: Card does not exist in the collection")

            emit Withdraw(id: token.id, from: self.owner?.address)
            
            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            var batchCollection <- create Collection()
            
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            
            return <-batchCollection
        }
        pub fun deposit(token: @NonFungibleToken.NFT) {
            

            let token <- token as! @BBCollectables.NFT

            let id = token.id

            let oldToken <- self.ownedNFTs[id] <- token

            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }

            destroy oldToken
        }

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            let keys = tokens.getIDs()

            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            destroy tokens
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowBBNft(id: UInt64): &BBCollectables.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &BBCollectables.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let BBNFT = nft as! &BBCollectables.NFT
            return BBNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <-create BBCollectables.Collection()
    }


    pub fun getAllCards(): {UInt32: BBCollectables.Card} {
        return BBCollectables.cardDatas
    }

    pub fun getCardMetaData(cardID: UInt32): {String: String}? {
        return self.cardDatas[cardID]?.metadata
    }

    pub fun getCardMetaDataByField(cardID: UInt32, field: String): String? {
        if let card = BBCollectables.cardDatas[cardID] {
            return card.metadata[field]
        } else {
            return nil
        }
    }

    pub fun getPackData(packID: UInt32): QueryPackData? {
        if BBCollectables.packs[packID] == nil {
            return nil
        } else {
            return QueryPackData(packID: packID)
        }
    }

    pub fun getPackName(packID: UInt32): String? {
        return BBCollectables.packDatas[packID]?.name
    }

    pub fun getPackIDsByName(packName: String): [UInt32]? {
        var packIDs: [UInt32] = []

        for packData in BBCollectables.packDatas.values {
            if packName == packData.name {

                packIDs.append(packData.packID)
            }
        }

        if packIDs.length == 0 {
            return nil
        } else {
            return packIDs
        }
    }

    pub fun getCardsInPack(packID: UInt32): [UInt32]? {

        return BBCollectables.packs[packID]?.cards
    }

    pub fun getRarityDistributionOfPack(packID: UInt32): {String: UInt256}? {

        return BBCollectables.packs[packID]?.rarityDistribution
    }

    pub fun isPackLocked(packID: UInt32): Bool? {
        return BBCollectables.packs[packID]?.locked
    }


    init() {

        // self.network = "testnet"

        self.cardDatas = {}
        self.packDatas = {}
        self.packs <- {}
        self.nextCardID = 1
        self.nextPackID = 1
        self.totalSupply = 0

        self.NftCollectionStoragePath = /storage/BBNFTCollection
        self.NftCollectionPublicPath = /public/BBNFTCollection
        self.AdminStoragePath = /storage/BBAdmin

        self.account.save<@Collection>(<- create Collection(), to: self.NftCollectionStoragePath)

        self.account.link<&BBCollectables.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(self.NftCollectionPublicPath, target: self.NftCollectionStoragePath)

        let adminResource: @BBCollectables.Admin <- create Admin()

        adminResource.createPack(name: "Coleção 2024", rarityDistribution: { "comum": 50, "raro": 30,"épico":16, "lendário": 4})

        self.account.save<@Admin>(<- adminResource, to: self.AdminStoragePath)

        emit ContractInitialized()

        
    }
}
 