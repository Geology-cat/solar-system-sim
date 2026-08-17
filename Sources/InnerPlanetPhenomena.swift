import Cocoa

/// 内惑星 (水星・金星) の見かけの姿を表す量
///
/// すべて地心 (地球中心) から見た値。光行差・光路時間・大気差の補正は
/// 行っていないため、精度については README / 技術解説を参照のこと。
struct InnerPlanetStatus {
    /// 太陽離角 [度] (0〜180)。太陽と惑星の地心方向のなす角。
    let elongationDeg: Double
    /// 東方離角なら true、西方離角なら false。
    /// 地心黄経差 Δλ = λ_planet - λ_sun の符号で判定する。
    let isEastern: Bool
    /// 位相角 i [度] (0〜180)。惑星から見た太陽と地球のなす角。
    let phaseAngleDeg: Double
    /// 輝面比 k = (1 + cos i) / 2 (0〜1)
    let illuminatedFraction: Double
    /// 視直径 [秒角]
    let apparentDiameterArcsec: Double
    /// 地心距離 Δ [AU]
    let geocentricDistanceAU: Double
    /// 日心距離 r [AU]
    let heliocentricDistanceAU: Double

    /// 「東方離角」「西方離角」の表示文字列
    var directionLabel: String {
        // 離角がごく小さいときは東西の区別に意味がない
        if elongationDeg < 0.05 { return "合付近" }
        return isEastern ? "東方" : "西方"
    }

    /// 満ち欠けの呼び名 (輝面比と位相角から素朴に分類)
    var phaseName: String {
        if illuminatedFraction < 0.04 { return "ほぼ暗黒" }
        if illuminatedFraction < 0.35 { return "細い三日月形" }
        if illuminatedFraction < 0.46 { return "三日月形" }
        if illuminatedFraction < 0.54 { return "半月形・二分" }
        if illuminatedFraction < 0.90 { return "凸形" }
        if illuminatedFraction < 0.98 { return "ほぼ円形" }
        return "円形"
    }
}

/// 内惑星に起こる主な現象
enum InnerPlanetEventKind {
    case inferiorConjunction      // 内合
    case superiorConjunction      // 外合
    case greatestEasternElongation // 東方最大離角
    case greatestWesternElongation // 西方最大離角

    var label: String {
        switch self {
        case .inferiorConjunction:       return "内合"
        case .superiorConjunction:       return "外合"
        case .greatestEasternElongation: return "東方最大離角"
        case .greatestWesternElongation: return "西方最大離角"
        }
    }
}

/// 現象の発生時刻とそのときの離角
struct InnerPlanetEvent {
    let kind: InnerPlanetEventKind
    let date: Date
    /// 最大離角のときはその離角 [度]。合のときは 0 に近い値。
    let elongationDeg: Double
}

/// 内惑星の見え方と現象時刻を求める
///
/// 座標はすべて `OrbitalMechanics.position3D` が返す
/// J2000.0 太陽中心黄道直交座標 [AU] を使う。z 成分を落とすと
/// 軌道傾斜 (水星 7.0°、金星 3.4°) の分だけ離角がずれるため、
/// ここでは必ず 3 次元で扱う。
struct InnerPlanetPhenomena {

    // MARK: - 瞬間の状態

    /// 指定時刻における内惑星の見かけの姿
    static func status(for planet: CelestialBody, at date: Date) -> InnerPlanetStatus {
        let rEarth = OrbitalMechanics.position3D(for: NASAElements.earth, at: date)
        let rPlanet = OrbitalMechanics.position3D(for: planet, at: date)
        return status(for: planet, rEarth: rEarth, rPlanet: rPlanet)
    }

    /// 位置ベクトルを与えて状態を組み立てる (探索ループから使う内部版)
    private static func status(for planet: CelestialBody,
                               rEarth: Vector3,
                               rPlanet: Vector3) -> InnerPlanetStatus {
        // 地心ベクトル
        let toPlanet = rPlanet - rEarth   // 地球 → 惑星
        let toSun = -rEarth               // 地球 → 太陽

        // 離角: 地心から見た太陽方向と惑星方向のなす角
        let elongation = toSun.angleDeg(to: toPlanet)

        // 東西の判別: 地心黄経差 Δλ = λ_planet - λ_sun を (-180, 180] へ畳む。
        // Δλ > 0 なら惑星は太陽より東 (東方離角 = 夕方の空に見える)。
        let deltaLambda = OrbitalMechanics.normalizeDegreesSigned(
            toPlanet.eclipticLongitudeDeg - toSun.eclipticLongitudeDeg
        )

        // 位相角 i: 惑星から見た太陽方向と地球方向のなす角
        let planetToSun = -rPlanet
        let planetToEarth = rEarth - rPlanet
        let phaseAngle = planetToSun.angleDeg(to: planetToEarth)

        let k = (1.0 + cos(OrbitalMechanics.deg2rad(phaseAngle))) / 2.0

        // 視直径 θ = 2R / Δ  (Δ は km 換算)
        let distanceAU = toPlanet.length
        let distanceKm = distanceAU * OrbitalMechanics.auInKm
        let diameterArcsec = distanceKm > 0
            ? 2.0 * planet.equatorialRadiusKm / distanceKm * OrbitalMechanics.arcsecPerRadian
            : 0.0

        return InnerPlanetStatus(
            elongationDeg: elongation,
            isEastern: deltaLambda > 0,
            phaseAngleDeg: phaseAngle,
            illuminatedFraction: k,
            apparentDiameterArcsec: diameterArcsec,
            geocentricDistanceAU: distanceAU,
            heliocentricDistanceAU: rPlanet.length
        )
    }

    // MARK: - 探索に使う 1 変数関数

    /// 地心黄経差 Δλ [度] ((-180, 180] に畳んだ値)。合ではこれが 0 を横切る。
    private static func deltaLambda(for planet: CelestialBody, at date: Date) -> Double {
        let rEarth = OrbitalMechanics.position3D(for: NASAElements.earth, at: date)
        let rPlanet = OrbitalMechanics.position3D(for: planet, at: date)
        let toPlanet = rPlanet - rEarth
        let toSun = -rEarth
        return OrbitalMechanics.normalizeDegreesSigned(
            toPlanet.eclipticLongitudeDeg - toSun.eclipticLongitudeDeg
        )
    }

    /// 離角 [度]。最大離角ではこれが極大になる。
    private static func elongation(for planet: CelestialBody, at date: Date) -> Double {
        let rEarth = OrbitalMechanics.position3D(for: NASAElements.earth, at: date)
        let rPlanet = OrbitalMechanics.position3D(for: planet, at: date)
        return (-rEarth).angleDeg(to: rPlanet - rEarth)
    }

    // MARK: - 現象時刻の探索

    /// 粗探索の刻み幅 [秒]。6 時間。
    ///
    /// 水星の会合周期は約 116 日で、内合前後では Δλ が 1 日に十数度動く。
    /// 1 日刻みだと符号反転を跨いで取り逃す危険があるため 6 時間まで詰める。
    private static let coarseStep: TimeInterval = 6 * 3600

    /// 探索を打ち切る上限 [秒]。金星の会合周期 (約 584 日) より十分長く取る。
    private static let searchHorizon: TimeInterval = 800 * 86400

    /// `from` 以降に最初に起こる 4 種類の現象を求める。
    ///
    /// 4 種すべてが見つかるか、探索上限に達したら終了する。
    /// 戻り値は発生時刻の昇順。
    static func upcomingEvents(for planet: CelestialBody, from start: Date) -> [InnerPlanetEvent] {
        var found: [InnerPlanetEventKind: InnerPlanetEvent] = [:]

        // 離角の極大判定には 3 点が要るので、常に (t0, t1, t2) の三つ組を保持して
        // 1 ステップずつずらしていく。合の判定は区間 [t0, t1] に対して行うので、
        // 探索開始直後 (6 時間以内) に起こる合も取りこぼさない。
        var t0 = start
        var t1 = start.addingTimeInterval(coarseStep)
        var dl0 = deltaLambda(for: planet, at: t0)
        var dl1 = deltaLambda(for: planet, at: t1)
        var el0 = elongation(for: planet, at: t0)
        var el1 = elongation(for: planet, at: t1)

        var elapsed: TimeInterval = 0
        while elapsed < searchHorizon && found.count < 4 {
            let t2 = t1.addingTimeInterval(coarseStep)
            let dl2 = deltaLambda(for: planet, at: t2)
            let el2 = elongation(for: planet, at: t2)

            // --- 合: 区間 [t0, t1] で Δλ が符号を変える ---
            // ±180° 付近での折り返しを合と誤検出しないよう、
            // 両端の絶対値の和が 180° 未満であることも確かめる。
            if (dl0 < 0) != (dl1 < 0), abs(dl0) + abs(dl1) < 180.0 {
                let tc = bisectZero(of: { deltaLambda(for: planet, at: $0) }, from: t0, to: t1)
                let kind = conjunctionKind(for: planet, at: tc)
                if found[kind] == nil {
                    found[kind] = InnerPlanetEvent(
                        kind: kind, date: tc,
                        elongationDeg: elongation(for: planet, at: tc)
                    )
                }
            }

            // --- 最大離角: 区間 [t0, t2] の内部で離角が極大 ---
            if el1 > el0 && el1 >= el2 {
                let tm = ternaryMaximum(of: { elongation(for: planet, at: $0) }, from: t0, to: t2)
                let elong = elongation(for: planet, at: tm)
                let kind: InnerPlanetEventKind = deltaLambda(for: planet, at: tm) > 0
                    ? .greatestEasternElongation
                    : .greatestWesternElongation
                if found[kind] == nil {
                    found[kind] = InnerPlanetEvent(kind: kind, date: tm, elongationDeg: elong)
                }
            }

            t0 = t1; dl0 = dl1; el0 = el1
            t1 = t2; dl1 = dl2; el1 = el2
            elapsed += coarseStep
        }

        return found.values.sorted(by: { $0.date < $1.date })
    }

    /// 合の時刻における地心距離を見て内合か外合かを決める。
    /// 内惑星が地球と太陽の間にあれば Δ < r_earth となる。
    private static func conjunctionKind(for planet: CelestialBody, at date: Date) -> InnerPlanetEventKind {
        let rEarth = OrbitalMechanics.position3D(for: NASAElements.earth, at: date)
        let rPlanet = OrbitalMechanics.position3D(for: planet, at: date)
        let geocentric = (rPlanet - rEarth).length
        return geocentric < rEarth.length ? .inferiorConjunction : .superiorConjunction
    }

    /// 二分法で f(t) = 0 を解く。区間の両端で符号が異なることを前提とする。
    private static func bisectZero(of f: (Date) -> Double, from a: Date, to b: Date) -> Date {
        var lo = a
        var hi = b
        // lo を動かすのは f(mid) が f(lo) と同符号のときだけなので、
        // f(lo) の符号は不変。最初に 1 度求めれば足りる。
        let fLo = f(lo)
        // 秒未満まで詰める (6 時間区間を 60 回二分すれば十分)
        for _ in 0..<60 {
            let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
            if hi.timeIntervalSince1970 - lo.timeIntervalSince1970 < 1.0 { return mid }
            let fMid = f(mid)
            if (fLo < 0) == (fMid < 0) { lo = mid } else { hi = mid }
        }
        return Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
    }

    /// 三分探索で単峰関数 f(t) の極大を求める。
    ///
    /// 極大点の近傍では f が平坦なので、値ではなく区間幅を収束条件にする。
    private static func ternaryMaximum(of f: (Date) -> Double, from a: Date, to b: Date) -> Date {
        var lo = a.timeIntervalSince1970
        var hi = b.timeIntervalSince1970
        for _ in 0..<100 {
            if hi - lo < 1.0 { break }
            let m1 = lo + (hi - lo) / 3.0
            let m2 = hi - (hi - lo) / 3.0
            if f(Date(timeIntervalSince1970: m1)) < f(Date(timeIntervalSince1970: m2)) {
                lo = m1
            } else {
                hi = m2
            }
        }
        return Date(timeIntervalSince1970: (lo + hi) / 2)
    }
}
