import Foundation

/// A one-off shop record. Milestones survive relighting; they are a history of the
/// workshop, not a currency faucet, so the reward is deliberately modest.
struct VitremberMilestone: Identifiable {
    let id: Int
    let title: String
    let detail: String
    /// Coins paid once, when the record is first set.
    let reward: Double
    let test: (VitremberSave) -> Bool
}

enum MilestoneCatalog {

    static let all: [VitremberMilestone] = [
        VitremberMilestone(id: 1, title: "First Gather", detail: "Finish any piece.",
                      reward: 20, test: { $0.piecesFinished >= 1 }),
        VitremberMilestone(id: 2, title: "Steady Hand", detail: "Finish 25 pieces.",
                      reward: 150, test: { $0.piecesFinished >= 25 }),
        VitremberMilestone(id: 3, title: "Shop Rhythm", detail: "Finish 250 pieces.",
                      reward: 2_500, test: { $0.piecesFinished >= 250 }),
        VitremberMilestone(id: 4, title: "A Life at the Bench", detail: "Finish 2,000 pieces.",
                      reward: 18_000, test: { $0.piecesFinished >= 2_000 }),

        VitremberMilestone(id: 5, title: "Held the Core", detail: "Make your first Masterwork.",
                      reward: 250, test: { $0.masterworksAllTime >= 1 }),
        VitremberMilestone(id: 6, title: "Ten Perfect Windows", detail: "Make 10 Masterworks.",
                      reward: 1_800, test: { $0.masterworksAllTime >= 10 }),
        VitremberMilestone(id: 7, title: "Gaffer's Reputation", detail: "Make 100 Masterworks.",
                      reward: 14_000, test: { $0.masterworksAllTime >= 100 }),
        VitremberMilestone(id: 8, title: "The Guild Notices", detail: "Make 500 Masterworks.",
                      reward: 160_000, test: { $0.masterworksAllTime >= 500 }),

        VitremberMilestone(id: 9, title: "Crack in the Glass", detail: "Lose a piece to the cold. It happens.",
                      reward: 25, test: { $0.piecesCracked >= 1 }),
        VitremberMilestone(id: 10, title: "Nothing Wasted", detail: "Salvage 20 pieces from the lehr.",
                      reward: 3_000, test: { $0.piecesSalvaged >= 20 }),

        VitremberMilestone(id: 11, title: "A Second Pair of Hands", detail: "Take on a second apprentice.",
                      reward: 100, test: { $0.level(.apprentice) >= 2 }),
        VitremberMilestone(id: 12, title: "A Full Shop", detail: "Employ all eight apprentices.",
                      reward: 40_000, test: { $0.level(.apprentice) >= 8 }),
        VitremberMilestone(id: 13, title: "Two Pieces, One Furnace", detail: "Open the second bench.",
                      reward: 1_500, test: { $0.level(.extraBench) >= 1 }),
        VitremberMilestone(id: 14, title: "Three at Once", detail: "Open the third bench.",
                      reward: 12_000, test: { $0.level(.extraBench) >= 2 }),

        VitremberMilestone(id: 15, title: "Better Brick", detail: "Take the Kiln Lining to level 6.",
                      reward: 2_000, test: { $0.level(.lining) >= 6 }),
        VitremberMilestone(id: 16, title: "A Finer Treadle", detail: "Take the Treadle Governor to level 5.",
                      reward: 4_000, test: { $0.level(.governor) >= 5 }),
        VitremberMilestone(id: 17, title: "Practised Eye", detail: "Take the Gaffer's Eye to level 3.",
                      reward: 12_000, test: { $0.level(.gaffersEye) >= 3 }),

        VitremberMilestone(id: 18, title: "Beyond the Bead", detail: "Unlock the Stemmed Goblet.",
                      reward: 900, test: { $0.allTimeEarnings >= VesselCatalog.kind(3).unlockLifetime }),
        VitremberMilestone(id: 19, title: "Cut and Polished", detail: "Unlock the Cut Decanter.",
                      reward: 6_000, test: { $0.allTimeEarnings >= VesselCatalog.kind(4).unlockLifetime }),
        VitremberMilestone(id: 20, title: "Room-Scale Work", detail: "Unlock the Chandelier Arm.",
                      reward: 300_000, test: { $0.allTimeEarnings >= VesselCatalog.kind(7).unlockLifetime }),

        VitremberMilestone(id: 21, title: "Relight", detail: "Bank the furnace and start again.",
                      reward: 500, test: { $0.relights >= 1 }),
        VitremberMilestone(id: 22, title: "Journeyman", detail: "Hold 5 Hallmarks.",
                      reward: 4_000, test: { $0.hallmarks >= 5 }),
        VitremberMilestone(id: 23, title: "Gaffer", detail: "Hold 15 Hallmarks.",
                      reward: 30_000, test: { $0.hallmarks >= 15 }),
        VitremberMilestone(id: 24, title: "Master Gaffer", detail: "Hold 35 Hallmarks.",
                      reward: 250_000, test: { $0.hallmarks >= 35 }),

        VitremberMilestone(id: 25, title: "Full Catalogue", detail: "Make at least one of every vessel.",
                      reward: 120_000, test: { save in
                          save.records.allSatisfy { $0.total > 0 }
                      }),
        VitremberMilestone(id: 26, title: "Nothing but the Best", detail: "Make a Masterwork of every vessel.",
                      reward: 900_000, test: { save in
                          save.records.allSatisfy { $0.byGrade.count > 3 && $0.byGrade[3] > 0 }
                      })
    ]
}
