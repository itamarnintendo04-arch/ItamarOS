#if os(iOS)
import SwiftUI

enum CloudClimbWorldVisuals {
    static func palette(_ world:Int) -> [Color] {
        switch world {
        case 1: return [.cyan,.blue]
        case 2: return [.pink,.orange]
        case 3: return [.purple,.indigo]
        case 4: return [.red,.orange]
        case 5: return [.blue,.teal]
        case 6: return [.green,.mint]
        case 7: return [.black,.purple]
        case 8: return [.white,.cyan]
        case 9: return [.indigo,.gray]
        case 10: return [.yellow,.orange]
        default: return [.purple,.black]
        }
    }
    static func name(_ world:Int) -> String {
        let names = ["Sky Islands","Candy Kingdom","Crystal Caves",
                     "Volcano Valley","Ocean Depths","Enchanted Forest",
                     "Galaxy","Frozen Peaks","Storm Realm","Golden Castle",
                     "Secret World"]
        return names[max(0,min(10,world-1))]
    }
}
#endif
