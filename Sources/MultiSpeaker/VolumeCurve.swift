import Foundation

/// 音量曲线：滑块位置 ↔ dB 的映射。
///
/// 直接把滑块线性映射到 dB（0~1 → -60~0dB）手感是灾难：拖到一半就是 -30dB，
/// 听感上几乎没声音了，用户会以为「稍微调小一点就哑了」。
/// 这里用分段折线近似等响感知：半格 ≈ -12dB，低位段加密、高位段留出增益余量。
enum VolumeCurve {
    /// 最低端（再往下就是静音）
    static let minDb: Double = -60
    /// 最大端。>0dB 是增益，用来榨干物理喇叭的余量；前提是音源本身别顶着 0dBFS
    static let maxDb: Double = 12

    /// 位置→dB 的锚点（位置递增、dB 递增）
    private static let anchors: [(pos: Double, db: Double)] = [
        (0.00, -60),
        (0.08, -44),
        (0.16, -34),
        (0.28, -24),
        (0.40, -16),
        (0.50, -12),
        (0.62, -8),
        (0.72, -5),
        (0.82, -2),
        (0.90, 3),
        (1.00, 12),
    ]

    /// 滑块位置（0…1）→ 增益（dB）
    static func db(forPosition p: Double) -> Double {
        let x = min(max(p, 0), 1)
        for i in 1..<anchors.count {
            let a = anchors[i - 1], b = anchors[i]
            if x <= b.pos {
                let t = (x - a.pos) / (b.pos - a.pos)
                return a.db + (b.db - a.db) * t
            }
        }
        return anchors.last!.db
    }

    /// 增益（dB）→ 滑块位置（0…1）
    static func position(forDb db: Double) -> Double {
        let v = min(max(db, minDb), maxDb)
        for i in 1..<anchors.count {
            let a = anchors[i - 1], b = anchors[i]
            if v <= b.db {
                let t = (v - a.db) / (b.db - a.db)
                return a.pos + (b.pos - a.pos) * t
            }
        }
        return 1
    }

    /// 位置 → 百分比（UI 显示用）
    static func percent(forPosition p: Double) -> Int {
        Int((min(max(p, 0), 1) * 100).rounded())
    }

    /// 是否已经到「静音」区（最左端 0.5% 以内）
    static func isSilent(_ p: Double) -> Bool { p <= 0.005 }
}
