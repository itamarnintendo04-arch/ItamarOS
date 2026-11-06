import SwiftUI
import SceneKit
import GameController

/// Original small open-world 3D prototype for ItamarOS Games.
/// Procedural models, terrain, trees, ruins and collectibles; no third-party assets.
struct OpenWorldAdventureView: View {
    @StateObject private var world = OpenWorldAdventureModel()
    @EnvironmentObject private var cloud: ItamarCloudService
    @State private var controllerTimer: Timer?
    @State private var lastDrag: CGSize = .zero
    var body: some View {
        Group {
            if cloud.isSignedIn {
                gameContent
            } else {
                ContentUnavailableView("Sign in required",systemImage:"lock.shield",description:Text("Sign in to your ItamarOS account to play Skybound Isles."))
            }
        }
    }

    private var gameContent: some View {
        ZStack(alignment:.top) {
            Skybound60FPSScene(scene:world.scene,camera:world.camera)
                .ignoresSafeArea()
                .simultaneousGesture(DragGesture(minimumDistance:5)
                    .onChanged { value in
                        world.rotateCamera(horizontal:Float(value.translation.width-lastDrag.width)*0.006,vertical:Float(value.translation.height-lastDrag.height)*0.004)
                        lastDrag=value.translation
                    }
                    .onEnded { _ in lastDrag = .zero })
            VStack {
                HStack {
                    Label("SKYBOUND ISLES",systemImage:"globe.europe.africa.fill")
                    Spacer()
                    Label("\(world.collected)/12",systemImage:"sparkle")
                }
                .font(.headline).foregroundStyle(.white)
                .padding(12)
                .background(.black.opacity(0.55),in:RoundedRectangle(cornerRadius:14))
                Spacer()
                HStack {
                    directionButton("arrow.left",dx:-1,dz:0)
                    directionButton("arrow.up",dx:0,dz:-1)
                    directionButton("arrow.down",dx:0,dz:1)
                    directionButton("arrow.right",dx:1,dz:0)
                }
                .padding(.bottom,25)
            }
            .padding(.horizontal,14)
        }
        .onAppear {
            controllerTimer?.invalidate()
            controllerTimer = Timer.scheduledTimer(withTimeInterval:1.0/30.0,repeats:true) { _ in
                guard let pad=GCController.controllers().first?.extendedGamepad else { return }
                let rx=pad.rightThumbstick.xAxis.value
                let ry=pad.rightThumbstick.yAxis.value
                if abs(rx)>0.12 || abs(ry)>0.12 {world.rotateCamera(horizontal:rx*0.045,vertical:-ry*0.035)}
                let dx=pad.leftThumbstick.xAxis.value
                let dz = -pad.leftThumbstick.yAxis.value
                if abs(dx)>0.15 || abs(dz)>0.15 {
                    world.move(dx:dx*0.12,dz:dz*0.12)
                }
            }
        }
        .onDisappear {
            controllerTimer?.invalidate()
            controllerTimer=nil
        }
        .navigationTitle("Skybound Isles")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func directionButton(_ icon:String,dx:Float,dz:Float)->some View {
        Button { world.move(dx:dx,dz:dz) } label: {
            Image(systemName:icon)
                .font(.title2.bold())
                .frame(maxWidth:.infinity,minHeight:56)
                .foregroundStyle(.white)
                .background(.indigo.opacity(0.8),in:RoundedRectangle(cornerRadius:12))
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class OpenWorldAdventureModel: ObservableObject {
    let scene = SCNScene()
    let camera = SCNNode()
    private let player = SCNNode()
    private var crystals:[SCNNode] = []
    private var cameraYaw:Float=0
    private var cameraPitch:Float=0.32
    @Published private(set) var collected = 0

    init() {
        scene.background.contents = UIColor(red:0.42,green:0.75,blue:0.98,alpha:1)
        scene.rootNode.addChildNode(camera)
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 70
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1100
        sun.eulerAngles = SCNVector3(-0.8,0.6,0)
        scene.rootNode.addChildNode(sun)
        scene.lightingEnvironment.contents = UIColor.white

        let ground = SCNNode(geometry:SCNBox(width:90,height:1,length:90,chamferRadius:1))
        ground.position = SCNVector3(0,-0.5,0)
        ground.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen
        scene.rootNode.addChildNode(ground)

        let body = SCNNode(geometry:SCNCapsule(capRadius:0.42,height:1.6))
        body.geometry?.firstMaterial?.diffuse.contents = UIColor.systemOrange
        body.position.y = 1
        player.addChildNode(body)
        let face = SCNNode(geometry:SCNSphere(radius:0.22))
        face.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        face.position = SCNVector3(0,1.5,-0.34)
        player.addChildNode(face)
        scene.rootNode.addChildNode(player)

        for i in 0..<75 {
            let x=Float((i*37+11)%83)-41
            let z=Float((i*53+17)%83)-41
            if abs(x)<4 && abs(z)<4 {continue}
            let trunk = SCNNode(geometry:SCNCylinder(radius:0.24,height:2.6))
            trunk.geometry?.firstMaterial?.diffuse.contents = UIColor.brown
            trunk.position=SCNVector3(x,1.3,z)
            scene.rootNode.addChildNode(trunk)
            let canopy=SCNNode(geometry:SCNCone(topRadius:0,bottomRadius:1.5,height:3.8))
            canopy.geometry?.firstMaterial?.diffuse.contents =
                i%3==0 ? UIColor.systemTeal : UIColor.systemGreen
            canopy.position=SCNVector3(x,3.6,z)
            scene.rootNode.addChildNode(canopy)
        }
        for i in 0..<12 {
            let x=Float((i*17+13)%69)-34
            let z=Float((i*29+9)%69)-34
            let gem=SCNNode(geometry:SCNPyramid(width:0.9,height:1.4,length:0.9))
            gem.geometry?.firstMaterial?.diffuse.contents = UIColor.systemCyan
            gem.geometry?.firstMaterial?.emission.contents = UIColor.systemBlue
            gem.position=SCNVector3(x,1,z)
            gem.runAction(.repeatForever(.rotateBy(x:0,y:CGFloat.pi*2,z:0,duration:3)))
            scene.rootNode.addChildNode(gem)
            crystals.append(gem)
        }
        for i in 0..<9 {
            let stone=SCNNode(geometry:SCNBox(width:2,height:Float(i%3+2),length:2,chamferRadius:0.15))
            stone.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGray
            stone.position=SCNVector3(Float(i*9-36),Float(i%3+2)/2,Float(i*7-28))
            scene.rootNode.addChildNode(stone)
        }
        updateCamera()
    }

    func move(dx:Float,dz:Float) {
        player.position.x=max(-43,min(43,player.position.x+dx*1.5))
        player.position.z=max(-43,min(43,player.position.z+dz*1.5))
        if dx != 0 || dz != 0 {player.eulerAngles.y=atan2f(-dx,-dz)}
        for gem in crystals where gem.parent != nil {
            let x=gem.position.x-player.position.x
            let z=gem.position.z-player.position.z
            if x*x+z*z<3 {
                gem.removeFromParentNode()
                collected += 1
            }
        }
        updateCamera()
    }
    func rotateCamera(horizontal:Float,vertical:Float) {
        cameraYaw += horizontal
        cameraPitch=max(-0.2,min(1.05,cameraPitch+vertical))
        updateCamera()
    }
    private func updateCamera() {
        let d:Float=12
        let h=d*cos(cameraPitch)
        camera.position=SCNVector3(player.position.x+sin(cameraYaw)*h,1.4+sin(cameraPitch)*d,player.position.z+cos(cameraYaw)*h)
        camera.look(at:SCNVector3(player.position.x,1.2,player.position.z))
    }
}

#if os(iOS)
private struct Skybound60FPSScene: UIViewRepresentable {
    let scene: SCNScene
    let camera: SCNNode
    func makeUIView(context:Context)->SCNView {
        let view=SCNView(frame:.zero)
        view.scene=scene
        view.pointOfView=camera
        view.isPlaying=true
        view.rendersContinuously=true
        view.preferredFramesPerSecond=60
        view.antialiasingMode = .multisampling4X
        return view
    }
    func updateUIView(_ view:SCNView,context:Context) {
        if view.scene !== scene {view.scene=scene}
        view.pointOfView=camera
    }
}
#endif
