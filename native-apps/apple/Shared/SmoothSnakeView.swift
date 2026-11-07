import SwiftUI
import Foundation

/// Continuous pixel-based Snake for iPhone, iPad and Mac.
/// No tile grid: 60fps updates, free steering and +11 px/s after every cherry.
struct SmoothSnakeView: View {
    @AppStorage("itamaros.games.snakebest") private var best=0
    @State private var segments=(0..<13).map { i in CGPoint(x:200-CGFloat(i)*11,y:200) }
    @State private var food=CGPoint(x:314,y:188)
    @State private var direction=CGVector(dx:1,dy:0)
    @State private var target=CGVector(dx:1,dy:0)
    @State private var running=false
    @State private var finished=false
    @State private var score=0
    @State private var lastDrag:CGSize = .zero
    @State private var previousTick=Date()
    private let timer=Timer.publish(every:1.0/60.0,on:.main,in:.common).autoconnect()
    private var speed:CGFloat { min(230,76+CGFloat(score)*11) }
    private let cell:CGFloat = 20

    var body: some View {
        VStack(spacing:12) {
            Text("Snake · Smooth movement").font(.title2.bold())
            Text("Score: \(score) · Best: \(best) · Speed: \(Int(speed)) px/s")
            steerableCanvas
            #if !os(tvOS)
            Text("Swipe to turn 90° at grid corners. Movement stays smooth.")
                .font(.caption).foregroundStyle(.secondary)
            #else
            Text("Use your Apple TV remote to steer. Every cherry makes the snake faster.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("↑"){ steer(dx:0,dy:-1) }
                Button("←"){ steer(dx:-1,dy:0) }
                Button("↓"){ steer(dx:0,dy:1) }
                Button("→"){ steer(dx:1,dy:0) }
            }
            #endif
            HStack {
                Button(finished ? "Try again" : running ? "Pause" : "Start") {
                    if finished { reset(); running=true; previousTick=Date() } else { running.toggle();previousTick=Date() }
                }
                Button("Restart") { reset() }
            }
            if finished { Text("Game over").foregroundStyle(.red) }
        }
        .onReceive(timer) { date in
            guard running else { previousTick=date;return }
            let dt=min(0.035,max(0,date.timeIntervalSince(previousTick)))
            previousTick=date
            tick(CGFloat(dt))
        }
        .onDisappear { running=false }
    }

    private var baseCanvas: some View {
        Canvas { context,size in
            let scale=min(size.width,size.height)/400
            func point(_ p:CGPoint)->CGPoint { CGPoint(x:p.x*scale,y:p.y*scale) }
            context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(Color(red:0.86,green:0.97,blue:0.9)))
            for i in 0..<42 {
                let x=CGFloat((i*79+47)%400)*scale,y=CGFloat((i*131+36)%400)*scale
                context.fill(Path(ellipseIn:CGRect(x:x-3*scale,y:y-3*scale,
                                                   width:6*scale,height:6*scale)),
                             with:.color(.green.opacity(0.12)))
            }
            let berry=point(food)
            for offset:CGFloat in [-5,5] {
                context.fill(Path(ellipseIn:CGRect(x:berry.x+(offset-8)*scale,y:berry.y-6*scale,
                    width:16*scale,height:16*scale)),with:.color(Color(red:0.87,green:0.07,blue:0.13)))
            }
            var stem=Path()
            stem.move(to:berry)
            stem.addLine(to:CGPoint(x:berry.x+2*scale,y:berry.y-14*scale))
            context.stroke(stem,with:.color(.green),
                           style:StrokeStyle(lineWidth:3*scale,lineCap:.round))
            context.fill(Path(ellipseIn:CGRect(x:berry.x+2*scale,y:berry.y-18*scale,width:13*scale,height:6*scale)),with:.color(.green))
            if segments.count>1 {
                var snakePath=Path()
                snakePath.move(to:point(segments[segments.count-1]))
                for p in segments.reversed().dropFirst() {
                    snakePath.addLine(to:point(p))
                }
                context.stroke(snakePath,with:.color(Color(red:0.13,green:0.53,blue:0.36)),
                               style:StrokeStyle(lineWidth:19*scale,lineCap:.round,lineJoin:.round))
                context.stroke(snakePath,with:.color(Color(red:0.48,green:0.89,blue:0.62)),
                               style:StrokeStyle(lineWidth:12*scale,lineCap:.round,lineJoin:.round))
            }
            if let head=segments.first {
                let h=point(head)
                context.fill(Path(ellipseIn:CGRect(x:h.x-11*scale,y:h.y-11*scale,
                   width:22*scale,height:22*scale)),with:.color(.green))
                for side:CGFloat in [-5,5] {
                    let eye=CGPoint(x:h.x+(direction.dx*4-direction.dy*side)*scale,
                                    y:h.y+(direction.dy*4+direction.dx*side)*scale)
                    context.fill(Path(ellipseIn:CGRect(x:eye.x-4*scale,y:eye.y-4*scale,
                        width:8*scale,height:8*scale)),with:.color(.white))
                    context.fill(Path(ellipseIn:CGRect(x:eye.x-2*scale+direction.dx*scale,
                        y:eye.y-2*scale+direction.dy*scale,width:4*scale,height:4*scale)),
                        with:.color(.black))
                }
            }
        }
        .aspectRatio(1,contentMode:.fit)
        .background(Color.green.opacity(0.15),in:RoundedRectangle(cornerRadius:14))
    }

    @ViewBuilder private var steerableCanvas: some View {
        #if os(tvOS)
        baseCanvas
        #else
        baseCanvas
            .gesture(DragGesture(minimumDistance:0).onChanged { event in
                let dx=event.translation.width-lastDrag.width
                let dy=event.translation.height-lastDrag.height
                let len=hypot(dx,dy)
                if len>2 {
                    let next:CGVector = abs(dx)>abs(dy) ? CGVector(dx:dx>0 ? 1 : -1,dy:0) : CGVector(dx:0,dy:dy>0 ? 1 : -1)
                    if next.dx*direction.dx+next.dy*direction.dy > -0.8 { target=next }
                    lastDrag=event.translation
                }
            }.onEnded { _ in lastDrag = .zero })
        #endif
    }

    private func steer(dx:CGFloat,dy:CGFloat) {
        if dx*direction.dx+dy*direction.dy > -0.8 {
            target=CGVector(dx:dx,dy:dy)
        }
    }

    private func length(_ a:CGPoint,_ b:CGPoint)->CGFloat {
        hypot(a.x-b.x,a.y-b.y)
    }

    private func tick(_ dt:CGFloat) {
        guard !segments.isEmpty else { return }
        // Advance in tiny pixel steps. Turns happen at 20px grid centers,
        // while the head and the trailing body animate continuously.
        let distance = speed * dt
        let steps = max(1, Int(ceil(distance / 2)))
        for _ in 0..<steps {
            guard let start = segments.first else { return }
            let stride = distance / CGFloat(steps)
            let wantsTurn = direction.dx * target.dx + direction.dy * target.dy == 0
            let nextX = (start.x / cell).rounded() * cell
            let nextY = (start.y / cell).rounded() * cell
            let onCenter = abs(start.x-nextX) < stride + 0.15 &&
                           abs(start.y-nextY) < stride + 0.15
            if wantsTurn && onCenter {
                segments[0] = CGPoint(x:nextX,y:nextY)
                direction = target
            }
            let current = segments[0]
            let newHead = CGPoint(x:current.x+direction.dx*stride,
                                  y:current.y+direction.dy*stride)
            if newHead.x < 8 || newHead.y < 8 || newHead.x > 392 || newHead.y > 392 ||
                segments.dropFirst(min(8,segments.count)).contains(where: {
                    length($0,newHead) < 11.2
                }) {
                finished = true; running = false
                #if os(iOS)
                GameSoundEffects.shared.play(.damage)
                #endif
                return
            }
            segments[0] = newHead
            for i in 1..<segments.count {
                let before=segments[i-1], point=segments[i]
                let dist=length(before,point)
                if dist > 11 {
                    let amount=(dist-11)/dist
                    segments[i]=CGPoint(x:point.x+(before.x-point.x)*amount,
                                        y:point.y+(before.y-point.y)*amount)
                }
            }
            if length(newHead,food) < 19 {
                if let end=segments.last { for _ in 0..<4 { segments.append(end) } }
                #if os(iOS)
                GameSoundEffects.shared.play(.coin)
                #endif
                score += 1; best=max(best,score)
                if let next=makeFood() { food=next }
                else { finished=true;running=false;return }
            }
        }
    }

    private func makeFood()->CGPoint? {
        for _ in 0..<250 {
            let p=CGPoint(x:CGFloat.random(in:18...382),
                          y:CGFloat.random(in:18...382))
            if segments.allSatisfy({length($0,p)>25}){return p}
        }
        return nil
    }
    private func reset() {
        segments=(0..<13).map { i in CGPoint(x:200-CGFloat(i)*11,y:200) }
        food=CGPoint(x:314,y:188)
        direction=CGVector(dx:1,dy:0);target=direction
        running=false;finished=false;score=0;previousTick=Date()
    }
}
