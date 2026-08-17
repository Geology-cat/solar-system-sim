import Cocoa

/// JPL Solar System Dynamics 公開の軌道要素
///
/// 出典: "Keplerian Elements for Approximate Positions of the Major Planets"
///   https://ssd.jpl.nasa.gov/planets/approx_pos.html
///   Table 2b (有効範囲: 3000 BC 〜 3000 AD)
///
/// 赤道半径は NASA Planetary Fact Sheet による。
struct NASAElements {
    static let planets: [CelestialBody] = [
        // 水星
        CelestialBody(name: "水星", color: .gray, radiusMultiplier: 0.38,
                      equatorialRadiusKm: 2439.7, elements: OrbitalElements(
            a: 0.38709843, e: 0.20563661, I: 7.00559432,
            L: 252.25166724, longPeri: 77.45771895, longNode: 48.33961819,
            aRate: 0.00000000, eRate: 0.00002123, IRate: -0.00590158,
            LRate: 149472.67486623, longPeriRate: 0.15940013, longNodeRate: -0.12214182
        )),
        // 金星
        CelestialBody(name: "金星", color: .orange, radiusMultiplier: 0.95,
                      equatorialRadiusKm: 6051.8, elements: OrbitalElements(
            a: 0.72332102, e: 0.00676399, I: 3.39777545,
            L: 181.97970850, longPeri: 131.76755713, longNode: 76.67261496,
            aRate: -0.00000026, eRate: -0.00005107, IRate: 0.00043494,
            LRate: 58517.81560260, longPeriRate: 0.05679648, longNodeRate: -0.27274174
        )),
        // 地球 (実際は地球-月の重心 EMB。地表からの観測でも誤差は地心-月心距離以下)
        CelestialBody(name: "地球", color: .blue, radiusMultiplier: 1.0,
                      equatorialRadiusKm: 6378.137, elements: OrbitalElements(
            a: 1.00000018, e: 0.01673163, I: -0.00054346,
            L: 100.46691572, longPeri: 102.93005885, longNode: -5.11260389,
            aRate: -0.00000003, eRate: -0.00003661, IRate: -0.01337178,
            LRate: 35999.37306329, longPeriRate: 0.31795260, longNodeRate: -0.24123856
        )),
        // 火星
        CelestialBody(name: "火星", color: .red, radiusMultiplier: 0.53,
                      equatorialRadiusKm: 3396.2, elements: OrbitalElements(
            a: 1.52371243, e: 0.09336511, I: 1.85181869,
            L: -4.56813164, longPeri: -23.91744784, longNode: 49.71320984,
            aRate: 0.00000097, eRate: 0.00009149, IRate: -0.00724757,
            LRate: 19140.29934243, longPeriRate: 0.45223625, longNodeRate: -0.26852431
        )),
        // 木星 (以降は平均近点角の補正項 b, c, s, f が必要)
        CelestialBody(name: "木星", color: .brown, radiusMultiplier: 11.2,
                      equatorialRadiusKm: 71492.0, elements: OrbitalElements(
            a: 5.20248019, e: 0.04853590, I: 1.29861416,
            L: 34.33479152, longPeri: 14.27495244, longNode: 100.29282654,
            aRate: -0.00002864, eRate: 0.00018026, IRate: -0.00322699,
            LRate: 3034.90371757, longPeriRate: 0.18199196, longNodeRate: 0.13024619,
            b: -0.00012452, c: 0.06064060, s: -0.35635438, f: 38.35125000
        )),
        // 土星
        CelestialBody(name: "土星", color: .yellow, radiusMultiplier: 9.45,
                      equatorialRadiusKm: 60268.0, elements: OrbitalElements(
            a: 9.54149883, e: 0.05550825, I: 2.49424102,
            L: 50.07571329, longPeri: 92.86136063, longNode: 113.63998702,
            aRate: -0.00003065, eRate: -0.00032044, IRate: 0.00451969,
            LRate: 1222.11494724, longPeriRate: 0.54179478, longNodeRate: -0.25015002,
            b: 0.00025899, c: -0.13434469, s: 0.87320147, f: 38.35125000
        )),
        // 天王星
        CelestialBody(name: "天王星", color: .cyan, radiusMultiplier: 4.0,
                      equatorialRadiusKm: 25559.0, elements: OrbitalElements(
            a: 19.18797948, e: 0.04685740, I: 0.77298127,
            L: 314.20276625, longPeri: 172.43404441, longNode: 73.96250215,
            aRate: -0.00020455, eRate: -0.00001550, IRate: -0.00180155,
            LRate: 428.49512595, longPeriRate: 0.09266985, longNodeRate: 0.05739699,
            b: 0.00058331, c: -0.97731848, s: 0.17689245, f: 7.67025000
        )),
        // 海王星
        CelestialBody(name: "海王星", color: .blue, radiusMultiplier: 3.88,
                      equatorialRadiusKm: 24764.0, elements: OrbitalElements(
            a: 30.06952752, e: 0.00895439, I: 1.77005520,
            L: 304.22289287, longPeri: 46.68158724, longNode: 131.78635853,
            aRate: 0.00006447, eRate: 0.00000818, IRate: 0.00022400,
            LRate: 218.46515314, longPeriRate: 0.01009938, longNodeRate: -0.00606302,
            b: -0.00041348, c: 0.68346318, s: -0.10162547, f: 7.67025000
        )),
        // 冥王星
        CelestialBody(name: "冥王星", color: .purple, radiusMultiplier: 0.18,
                      equatorialRadiusKm: 1188.3, elements: OrbitalElements(
            a: 39.48686035, e: 0.24885238, I: 17.14104260,
            L: 238.96535011, longPeri: 224.09702598, longNode: 110.30167986,
            aRate: 0.00449751, eRate: 0.00006016, IRate: 0.00000501,
            LRate: 145.18042903, longPeriRate: -0.00968827, longNodeRate: -0.00809981,
            b: -0.01262724, c: 0.0, s: 0.0, f: 0.0
        ))
    ]

    /// 名前で天体を引く
    static func body(named name: String) -> CelestialBody? {
        return planets.first(where: { $0.name == name })
    }

    /// 地球 (内惑星現象の計算で基準となる観測地)
    static let earth: CelestialBody = body(named: "地球")!

    /// サイドパネルで扱う内惑星
    static let innerPlanets: [CelestialBody] = [body(named: "水星")!, body(named: "金星")!]
}
