#if os(iOS)
import SwiftUI

/// Original deterministic enemies, launch pads and a middle-stage checkpoint.
/// These elements do not change cloud currency or create unlocks.
enum CloudClimbStageExtras {
    static let checkpointIndex=3
    static let patrols=[2,4]
    static let launchPads=[1,5]

    static func enemyX(_ p:CGRect,index:Int,time:TimeInterval)->CGFloat {
        p.midX + CGFloat(sin(time*(1.45+Double(index)*0.15)+Double(index)))*p.width*0.28
    }

    static func isDanger(x:CGFloat,y:CGFloat,stages:[CGRect],time:TimeInterval)->Bool {
        patrols.contains { index in
            guard stages.indices.contains(index) else{return false}
            let p=stages[index]
            return abs(x-enemyX(p,index:index,time:time))<16 &&
                   abs(y-(p.minY-10))<17
        }
    }

    static func isSpring(index:Int,x:CGFloat,platform:CGRect)->Bool {
        launchPads.contains(index) && abs(x-(platform.minX+platform.width*0.22))<18
    }

    static func draw(_ ctx:GraphicsContext,platforms:[CGRect],
                     sx:CGFloat,sy:CGFloat,time:TimeInterval,
                     checkpointActive:Bool) {
        for index in launchPads where platforms.indices.contains(index) {
            let p=platforms[index],x=(p.minX+p.width*0.22)*sx
            let rect=CGRect(x:x-15*sx,y:(p.minY-9)*sy,width:30*sx,height:9*sy)
            ctx.fill(Path(roundedRect:rect,cornerRadius:4),with:.color(.yellow))
            ctx.fill(Path(ellipseIn:CGRect(x:x-5*sx,y:(p.minY-18)*sy,
                width:10*sx,height:10*sy)),with:.color(.pink))
        }
        if platforms.indices.contains(checkpointIndex) {
            let p=platforms[checkpointIndex],x=p.midX*sx,y=(p.minY-37)*sy
            var line=Path()
            line.move(to:CGPoint(x:x,y:y))
            line.addLine(to:CGPoint(x:x,y:(p.minY-4)*sy))
            ctx.stroke(line,with:.color(.white),lineWidth:2)
            ctx.fill(Path(ellipseIn:CGRect(x:x-11*sx,y:y-11*sy,
                width:22*sx,height:22*sy)),
                with:.color(checkpointActive ? .mint : .yellow))
        }
        for index in patrols where platforms.indices.contains(index) {
            let p=platforms[index]
            let x=enemyX(p,index:index,time:time)*sx,y=(p.minY-13)*sy
            ctx.fill(Path(ellipseIn:CGRect(x:x-13*sx,y:y-13*sy,
                width:26*sx,height:26*sy)),with:.color(.purple))
            for delta in [-4.0,4.0] {
                ctx.fill(Path(ellipseIn:CGRect(x:x+delta*sx-3*sx,y:y-4*sy,
                    width:6*sx,height:6*sy)),with:.color(.white))
            }
        }
    }
}
#endif
