import SwiftUI

public enum CorbieRavenSide: CaseIterable, Sendable {
    case left
    case right
}

public struct CorbieRavenShape: Shape {
    public let side: CorbieRavenSide

    public init(side: CorbieRavenSide) {
        self.side = side
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        CorbieMarkGeometry.outline(for: side).add(to: &path, in: CorbieMarkGeometry.fitted(in: rect))
        return path
    }
}

public struct CorbieMarkShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let box = CorbieMarkGeometry.fitted(in: rect)
        for side in CorbieRavenSide.allCases {
            CorbieMarkGeometry.outline(for: side).add(to: &path, in: box)
        }
        return path
    }
}

public enum CorbieMarkGeometry {
    public static let aspectRatio: CGFloat = 0.8997

    public static func fitted(in rect: CGRect) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }
        let size: CGSize
        if rect.width / rect.height > aspectRatio {
            size = CGSize(width: rect.height * aspectRatio, height: rect.height)
        } else {
            size = CGSize(width: rect.width, height: rect.width / aspectRatio)
        }
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    static func outline(for side: CorbieRavenSide) -> RavenOutline {
        switch side {
        case .left: return leftRaven
        case .right: return rightRaven
        }
    }

    static let leftRaven = RavenOutline(
        start: CGPoint(x: 0.1038, y: 0.3252),
        curves: [
            UnitCurve(0.1153, 0.3063, 0.1291, 0.2896, 0.1437, 0.2733),
            UnitCurve(0.1580, 0.2574, 0.1708, 0.2407, 0.1770, 0.2207),
            UnitCurve(0.1893, 0.1811, 0.1612, 0.1534, 0.1263, 0.1466),
            UnitCurve(0.0892, 0.1393, 0.0532, 0.1426, 0.0196, 0.1600),
            UnitCurve(0.0148, 0.1624, 0.0098, 0.1672, 0.0038, 0.1634),
            UnitCurve(-0.0023, 0.1595, 0.0004, 0.1533, 0.0017, 0.1481),
            UnitCurve(0.0081, 0.1221, 0.0275, 0.1051, 0.0513, 0.0913),
            UnitCurve(0.0637, 0.0841, 0.0768, 0.0779, 0.0904, 0.0727),
            UnitCurve(0.1098, 0.0652, 0.1268, 0.0548, 0.1419, 0.0414),
            UnitCurve(0.1723, 0.0144, 0.2092, 0.0000, 0.2521, 0.0000),
            UnitCurve(0.3223, -0.0000, 0.3867, 0.0449, 0.4063, 0.1060),
            UnitCurve(0.4132, 0.1278, 0.4157, 0.1500, 0.4176, 0.1722),
            UnitCurve(0.4212, 0.2155, 0.4394, 0.2533, 0.4680, 0.2877),
            UnitCurve(0.4732, 0.2939, 0.4775, 0.3007, 0.4822, 0.3073),
            UnitCurve(0.4829, 0.3084, 0.4833, 0.3097, 0.4840, 0.3112),
            UnitCurve(0.4797, 0.3129, 0.4779, 0.3099, 0.4756, 0.3084),
            UnitCurve(0.4440, 0.2875, 0.4111, 0.2685, 0.3731, 0.2581),
            UnitCurve(0.3104, 0.2409, 0.2502, 0.2451, 0.1933, 0.2759),
            UnitCurve(0.1907, 0.2773, 0.1877, 0.2783, 0.1856, 0.2816),
            UnitCurve(0.2109, 0.2755, 0.2356, 0.2709, 0.2613, 0.2703),
            UnitCurve(0.3249, 0.2690, 0.3798, 0.2888, 0.4288, 0.3239),
            UnitCurve(0.4440, 0.3348, 0.4582, 0.3467, 0.4713, 0.3597),
            UnitCurve(0.4842, 0.3725, 0.4860, 0.3861, 0.4765, 0.4012),
            UnitCurve(0.4597, 0.4280, 0.4446, 0.4555, 0.4347, 0.4852),
            UnitCurve(0.4099, 0.5592, 0.4154, 0.6317, 0.4474, 0.7030),
            UnitCurve(0.4583, 0.7272, 0.4701, 0.7511, 0.4850, 0.7734),
            UnitCurve(0.4978, 0.7924, 0.4998, 0.8116, 0.4943, 0.8327),
            UnitCurve(0.4803, 0.8862, 0.4729, 0.9407, 0.4669, 0.9954),
            UnitCurve(0.4668, 0.9969, 0.4672, 0.9986, 0.4646, 0.9997),
            UnitCurve(0.4598, 0.9964, 0.4575, 0.9913, 0.4547, 0.9867),
            UnitCurve(0.4126, 0.9183, 0.3686, 0.8508, 0.3289, 0.7812),
            UnitCurve(0.3260, 0.7762, 0.3222, 0.7724, 0.3172, 0.7690),
            UnitCurve(0.2366, 0.7143, 0.1669, 0.6506, 0.1166, 0.5710),
            UnitCurve(0.0919, 0.5320, 0.0754, 0.4906, 0.0717, 0.4456),
            UnitCurve(0.0681, 0.4027, 0.0807, 0.3631, 0.1038, 0.3252)
        ]
    )

    static let rightRaven = RavenOutline(
        start: CGPoint(x: 0.5180, y: 0.8614),
        curves: [
            UnitCurve(0.5165, 0.8495, 0.5152, 0.8384, 0.5136, 0.8273),
            UnitCurve(0.5091, 0.7958, 0.4931, 0.7677, 0.4812, 0.7385),
            UnitCurve(0.4703, 0.7118, 0.4548, 0.6869, 0.4453, 0.6597),
            UnitCurve(0.4249, 0.6011, 0.4256, 0.5425, 0.4472, 0.4845),
            UnitCurve(0.4756, 0.4082, 0.5270, 0.3472, 0.6027, 0.3039),
            UnitCurve(0.6625, 0.2697, 0.7278, 0.2624, 0.7964, 0.2775),
            UnitCurve(0.8017, 0.2787, 0.8071, 0.2799, 0.8124, 0.2811),
            UnitCurve(0.8126, 0.2812, 0.8129, 0.2810, 0.8143, 0.2805),
            UnitCurve(0.7942, 0.2679, 0.7728, 0.2594, 0.7498, 0.2543),
            UnitCurve(0.6820, 0.2391, 0.6201, 0.2532, 0.5621, 0.2853),
            UnitCurve(0.5495, 0.2923, 0.5377, 0.3003, 0.5255, 0.3078),
            UnitCurve(0.5230, 0.3093, 0.5207, 0.3117, 0.5166, 0.3113),
            UnitCurve(0.5162, 0.3070, 0.5193, 0.3041, 0.5216, 0.3010),
            UnitCurve(0.5318, 0.2871, 0.5425, 0.2735, 0.5524, 0.2594),
            UnitCurve(0.5713, 0.2325, 0.5790, 0.2025, 0.5825, 0.1713),
            UnitCurve(0.5856, 0.1441, 0.5883, 0.1170, 0.5996, 0.0911),
            UnitCurve(0.6365, 0.0071, 0.7507, -0.0260, 0.8339, 0.0237),
            UnitCurve(0.8436, 0.0295, 0.8525, 0.0363, 0.8605, 0.0438),
            UnitCurve(0.8725, 0.0551, 0.8868, 0.0632, 0.9025, 0.0698),
            UnitCurve(0.9290, 0.0809, 0.9557, 0.0919, 0.9763, 0.1116),
            UnitCurve(0.9886, 0.1233, 0.9967, 0.1367, 0.9995, 0.1527),
            UnitCurve(1.0002, 0.1567, 1.0007, 0.1608, 0.9967, 0.1635),
            UnitCurve(0.9925, 0.1666, 0.9883, 0.1641, 0.9847, 0.1621),
            UnitCurve(0.9587, 0.1476, 0.9301, 0.1425, 0.8999, 0.1433),
            UnitCurve(0.8880, 0.1436, 0.8763, 0.1452, 0.8650, 0.1488),
            UnitCurve(0.8301, 0.1598, 0.8134, 0.1882, 0.8232, 0.2204),
            UnitCurve(0.8283, 0.2369, 0.8374, 0.2518, 0.8492, 0.2651),
            UnitCurve(0.8728, 0.2916, 0.8950, 0.3189, 0.9099, 0.3505),
            UnitCurve(0.9323, 0.3980, 0.9341, 0.4464, 0.9190, 0.4958),
            UnitCurve(0.9047, 0.5428, 0.8782, 0.5843, 0.8463, 0.6230),
            UnitCurve(0.7995, 0.6800, 0.7437, 0.7291, 0.6801, 0.7710),
            UnitCurve(0.6769, 0.7731, 0.6749, 0.7757, 0.6731, 0.7788),
            UnitCurve(0.6310, 0.8513, 0.5851, 0.9221, 0.5408, 0.9935),
            UnitCurve(0.5393, 0.9959, 0.5384, 0.9990, 0.5334, 1.0000),
            UnitCurve(0.5283, 0.9539, 0.5232, 0.9080, 0.5180, 0.8614)
        ]
    )
}

struct RavenOutline {
    let start: CGPoint
    let curves: [UnitCurve]

    func add(to path: inout Path, in box: CGRect) {
        path.move(to: start.scaled(in: box))
        for curve in curves {
            path.addCurve(
                to: curve.end.scaled(in: box),
                control1: curve.control1.scaled(in: box),
                control2: curve.control2.scaled(in: box)
            )
        }
        path.closeSubpath()
    }
}

struct UnitCurve {
    let control1: CGPoint
    let control2: CGPoint
    let end: CGPoint

    init(_ c1x: CGFloat, _ c1y: CGFloat, _ c2x: CGFloat, _ c2y: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        control1 = CGPoint(x: c1x, y: c1y)
        control2 = CGPoint(x: c2x, y: c2y)
        end = CGPoint(x: x, y: y)
    }
}

private extension CGPoint {
    func scaled(in box: CGRect) -> CGPoint {
        CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height)
    }
}
