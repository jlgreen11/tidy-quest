import Testing
@testable import TidyQuestCore

// MARK: - Tier token tests

@Suite("Tier tokens")
struct TierTests {

    // MARK: tileCornerRadius

    @Test("tileCornerRadius values are distinct across tiers")
    func tileCornerRadiusDistinct() {
        let radii = [Tier.starter.tileCornerRadius, Tier.standard.tileCornerRadius, Tier.advanced.tileCornerRadius]
        #expect(Set(radii).count == 3, "Each tier must have a unique tileCornerRadius")
    }

    @Test("tileCornerRadius: starter > standard > advanced")
    func tileCornerRadiusOrdering() {
        #expect(Tier.starter.tileCornerRadius > Tier.standard.tileCornerRadius)
        #expect(Tier.standard.tileCornerRadius > Tier.advanced.tileCornerRadius)
    }

    @Test("tileCornerRadius exact values")
    func tileCornerRadiusValues() {
        #expect(Tier.starter.tileCornerRadius == 28)
        #expect(Tier.standard.tileCornerRadius == 20)
        #expect(Tier.advanced.tileCornerRadius == 14)
    }

    // MARK: minTapTarget

    @Test("minTapTarget values are distinct across tiers")
    func minTapTargetDistinct() {
        let targets = [Tier.starter.minTapTarget, Tier.standard.minTapTarget, Tier.advanced.minTapTarget]
        #expect(Set(targets).count == 3, "Each tier must have a unique minTapTarget")
    }

    @Test("minTapTarget: starter >= standard >= advanced")
    func minTapTargetOrdering() {
        #expect(Tier.starter.minTapTarget >= Tier.standard.minTapTarget)
        #expect(Tier.standard.minTapTarget >= Tier.advanced.minTapTarget)
    }

    @Test("minTapTarget exact values")
    func minTapTargetValues() {
        #expect(Tier.starter.minTapTarget == 60)
        #expect(Tier.standard.minTapTarget == 56)
        #expect(Tier.advanced.minTapTarget == 44)
    }

    // MARK: useIllustratedIcons

    @Test("Only starter uses illustrated icons")
    func useIllustratedIcons() {
        #expect(Tier.starter.useIllustratedIcons == true)
        #expect(Tier.standard.useIllustratedIcons == false)
        #expect(Tier.advanced.useIllustratedIcons == false)
    }

    // MARK: showNumericBalance

    @Test("Starter hides numeric balance; others show it")
    func showNumericBalance() {
        #expect(Tier.starter.showNumericBalance == false)
        #expect(Tier.standard.showNumericBalance == true)
        #expect(Tier.advanced.showNumericBalance == true)
    }

    // MARK: motionDensity

    @Test("Advanced tier uses reduced motion; others use standard")
    func motionDensity() {
        #expect(Tier.starter.motionDensity == .standard)
        #expect(Tier.standard.motionDensity == .standard)
        #expect(Tier.advanced.motionDensity == .reduced)
    }
}

// MARK: - KidColor tests

@Suite("KidColor palette")
struct KidColorTests {

    @Test("All 8 cases exist")
    func allCasesCount() {
        #expect(KidColor.allCases.count == 8)
    }

    @Test("All hex values are 6-character strings")
    func hexFormat() {
        for color in KidColor.allCases {
            #expect(color.hex.count == 6, "\(color.rawValue) hex should be 6 chars, got '\(color.hex)'")
        }
    }

    @Test("All hex values are distinct")
    func hexDistinct() {
        let hexes = KidColor.allCases.map(\.hex)
        #expect(Set(hexes).count == hexes.count, "Every KidColor must have a unique hex")
    }

    @Test("All icon values are non-empty")
    func iconsNonEmpty() {
        for color in KidColor.allCases {
            #expect(!color.icon.isEmpty, "\(color.rawValue) must have an icon")
        }
    }

    @Test("All icon values are distinct")
    func iconsDistinct() {
        let icons = KidColor.allCases.map(\.icon)
        #expect(Set(icons).count == icons.count, "Every KidColor must have a unique icon")
    }

    @Test("Known hex values match architecture spec")
    func knownHexValues() {
        #expect(KidColor.coral.hex     == "FF6B6B")
        #expect(KidColor.sunflower.hex == "FFD93D")
        #expect(KidColor.sage.hex      == "6BCB77")
        #expect(KidColor.sky.hex       == "4D96FF")
        #expect(KidColor.lavender.hex  == "B983FF")
        #expect(KidColor.rose.hex      == "FF8FB1")
        #expect(KidColor.olive.hex     == "8BA888")
        #expect(KidColor.slate.hex     == "6C757D")
    }

    @Test("Known icon values match architecture spec")
    func knownIconValues() {
        #expect(KidColor.coral.icon     == "star.fill")
        #expect(KidColor.sunflower.icon == "sun.max.fill")
        #expect(KidColor.sage.icon      == "leaf.fill")
        #expect(KidColor.sky.icon       == "cloud.fill")
        #expect(KidColor.lavender.icon  == "moon.stars.fill")
        #expect(KidColor.rose.icon      == "heart.fill")
        #expect(KidColor.olive.icon     == "tree.fill")
        #expect(KidColor.slate.icon     == "circle.grid.3x3.fill")
    }
}
