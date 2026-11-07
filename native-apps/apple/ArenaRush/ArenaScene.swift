import SpriteKit
import UIKit

final class ArenaScene: SKScene {
    struct Fighter {
        var node: SKShapeNode
        var health: CGFloat
        var maxHealth: CGFloat
        var speed: CGFloat
        var lastShot: TimeInterval = 0
        var wander = CGVector(dx: 0, dy: 0)
    }
    var moveInput = CGVector.zero
    var fireInput = CGVector.zero
    var onState: ((Int, Int, Double) -> Void)?
    private var player: Fighter!
    private var enemies: [Fighter] = []
    private var bullets: [SKShapeNode] = []
    private var pickups: [SKShapeNode] = []
    private var obstacles: [SKShapeNode] = []
    private var score = 0
    private var charge: Double = 0
    private var lastTime: TimeInterval = 0
    private var spawnClock: TimeInterval = 0
    private var pickupClock: TimeInterval = 0
    private var fireClock: TimeInterval = 0
    private var enemyShotClock: TimeInterval = 0
    private let hero: Int
    private let difficulty: Int
    private let field = CGSize(width: 1000, height: 560)

    init(size: CGSize, hero: Int, difficulty: Int) {
        self.hero = hero
        self.difficulty = difficulty
        super.init(size: size)
        backgroundColor = UIColor(red: 0.06, green: 0.16, blue: 0.22, alpha: 1)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        removeAllChildren()
        let floor = SKShapeNode(rectOf: field, cornerRadius: 18)
        floor.fillColor = UIColor(red: 0.10, green: 0.30, blue: 0.28, alpha: 1)
        floor.strokeColor = .systemMint
        floor.lineWidth = 7
        floor.zPosition = -5
        addChild(floor)
        for x in stride(from: -480.0, through: 480.0, by: 80.0) {
            let line = SKShapeNode(rectOf: CGSize(width: 1, height: 540))
            line.position.x = x
            line.fillColor = UIColor.white.withAlphaComponent(0.07)
            line.strokeColor = .clear
            line.zPosition = -4
            addChild(line)
        }
        for y in stride(from: -250.0, through: 250.0, by: 80.0) {
            let line = SKShapeNode(rectOf: CGSize(width: 970, height: 1))
            line.position.y = y
            line.fillColor = UIColor.white.withAlphaComponent(0.07)
            line.strokeColor = .clear
            line.zPosition = -4
            addChild(line)
        }
        for p in [CGPoint(x:-220,y:135),CGPoint(x:160,y:-125),CGPoint(x:330,y:110),CGPoint(x:-340,y:-110)] {
            let rock = SKShapeNode(rectOf: CGSize(width: 85, height: 56), cornerRadius: 15)
            rock.fillColor = UIColor(red:0.20,green:0.40,blue:0.45,alpha:1)
            rock.strokeColor = UIColor(red:0.48,green:0.72,blue:0.74,alpha:1)
            rock.lineWidth = 5
            rock.position = p
            rock.zPosition = 2
            addChild(rock)
            obstacles.append(rock)
        }
        let colors: [UIColor] = [.systemCyan, .systemYellow, .systemOrange]
        let node = makeFighter(color: colors[hero % colors.count], at: CGPoint(x:0,y:0), radius: 22)
        node.name = "player"
        player = Fighter(node: node, health: 100, maxHealth: 100, speed: hero == 1 ? 245 : 210)
        onState?(100,0,0)
    }

    private func makeFighter(color: UIColor, at position: CGPoint, radius: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = color
        node.strokeColor = .white
        node.lineWidth = 4
        node.glowWidth = 3
        node.position = position
        node.zPosition = 8
        let eye1 = SKShapeNode(circleOfRadius: 4)
        eye1.fillColor = .white; eye1.strokeColor = .clear
        eye1.position = CGPoint(x:-7,y:5)
        let eye2 = SKShapeNode(circleOfRadius: 4)
        eye2.fillColor = .white; eye2.strokeColor = .clear
        eye2.position = CGPoint(x:7,y:5)
        node.addChild(eye1); node.addChild(eye2)
        addChild(node)
        return node
    }

    private func spawnEnemy() {
        guard enemies.count < 12 else { return }
        let edge = Int.random(in: 0...3)
        let pos: CGPoint
        switch edge {
        case 0: pos = CGPoint(x:CGFloat.random(in:-450...450),y:245)
        case 1: pos = CGPoint(x:CGFloat.random(in:-450...450),y:-245)
        case 2: pos = CGPoint(x:460,y:CGFloat.random(in:-230...230))
        default: pos = CGPoint(x:-460,y:CGFloat.random(in:-230...230))
        }
        let colors: [UIColor] = [.systemPink, .systemPurple, .systemRed]
        let node = makeFighter(color: colors.randomElement()!, at: pos, radius: 19)
        node.name = "enemy"
        enemies.append(Fighter(node: node, health: 55 + CGFloat(difficulty)*18,
                               maxHealth: 55 + CGFloat(difficulty)*18,
                               speed: 72 + CGFloat(difficulty)*28))
    }

    private func clamp(_ p: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(x:max(-485+radius,min(485-radius,p.x)),
                y:max(-265+radius,min(265-radius,p.y)))
    }
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x-b.x,a.y-b.y) }
    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        return length > 0.01 ? CGVector(dx:vector.dx/length,dy:vector.dy/length) : .zero
    }
    private func canOccupy(_ p: CGPoint, radius: CGFloat) -> Bool {
        for obstacle in obstacles {
            if abs(p.x-obstacle.position.x) < 43+radius &&
               abs(p.y-obstacle.position.y) < 29+radius { return false }
        }
        return true
    }
    private func move(_ node: SKNode, direction: CGVector, speed: CGFloat, dt: CGFloat, radius: CGFloat) {
        let dx = direction.dx*speed*dt, dy = direction.dy*speed*dt
        let x = clamp(CGPoint(x:node.position.x+dx,y:node.position.y),radius:radius)
        if canOccupy(x,radius:radius) { node.position.x=x.x }
        let y = clamp(CGPoint(x:node.position.x,y:node.position.y+dy),radius:radius)
        if canOccupy(y,radius:radius) { node.position.y=y.y }
    }
    private func shoot(from origin: CGPoint, direction: CGVector, enemy: Bool, damage: CGFloat = 25) {
        let dir = normalized(direction)
        guard hypot(dir.dx,dir.dy)>0.1 else { return }
        let bullet = SKShapeNode(circleOfRadius: enemy ? 6 : 8)
        bullet.fillColor = enemy ? .systemPink : .systemYellow
        bullet.strokeColor = .white
        bullet.lineWidth = 2
        bullet.position = CGPoint(x:origin.x+dir.dx*27,y:origin.y+dir.dy*27)
        bullet.zPosition = 6
        bullet.name = enemy ? "enemyBullet" : "heroBullet"
        bullet.userData = NSMutableDictionary(dictionary: [
            "vx": Double(dir.dx * (enemy ? 360 : 530)),
            "vy": Double(dir.dy * (enemy ? 360 : 530)),
            "damage": Double(damage)
        ])
        addChild(bullet)
        bullets.append(bullet)
    }

    func activateSuper() {
        guard charge >= 1, player.health > 0 else { return }
        charge = 0
        let ring = SKShapeNode(circleOfRadius: 22)
        ring.strokeColor = .systemYellow
        ring.lineWidth = 10
        ring.position = player.node.position
        ring.zPosition = 10
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 9, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        for i in enemies.indices.reversed() {
            if distance(enemies[i].node.position,player.node.position)<195 {
                enemies[i].health -= 85
                if enemies[i].health <= 0 { defeatEnemy(at:i) }
            }
        }
        player.health = min(player.maxHealth, player.health+15)
        onState?(Int(player.health),score,charge)
    }

    private func defeatEnemy(at index: Int) {
        let pos = enemies[index].node.position
        enemies[index].node.removeFromParent()
        enemies.remove(at:index)
        score += 10
        charge = min(1, charge+0.16)
        if Int.random(in:0...3)==0 { createPickup(at:pos) }
        let pop = SKLabelNode(text: "+10")
        pop.fontName = "AvenirNext-Bold"
        pop.fontSize = 24
        pop.fontColor = .yellow
        pop.position = pos
        pop.zPosition = 12
        addChild(pop)
        pop.run(.sequence([.group([.moveBy(x:0,y:38,duration:0.5),.fadeOut(withDuration:0.5)]),.removeFromParent()]))
    }
    private func createPickup(at p: CGPoint) {
        let node = SKShapeNode(circleOfRadius: 13)
        node.fillColor = .systemGreen
        node.strokeColor = .white
        node.lineWidth = 3
        node.position = p
        node.zPosition = 4
        node.name = "health"
        addChild(node)
        pickups.append(node)
    }

    override func update(_ currentTime: TimeInterval) {
        guard player != nil, player.health > 0 else { return }
        if lastTime == 0 { lastTime=currentTime; return }
        let dt = CGFloat(min(1.0/20.0,max(0,currentTime-lastTime)))
        lastTime=currentTime
        spawnClock += TimeInterval(dt)
        pickupClock += TimeInterval(dt)
        fireClock += TimeInterval(dt)
        enemyShotClock += TimeInterval(dt)
        if spawnClock >= max(0.7, 2.1-Double(difficulty)*0.35) {
            spawnClock=0
            spawnEnemy()
        }
        if pickupClock > 17 {
            pickupClock=0
            createPickup(at:CGPoint(x:CGFloat.random(in:-350...350),y:CGFloat.random(in:-180...180)))
        }
        move(player.node,direction:normalized(moveInput),speed:player.speed,dt:dt,radius:23)
        if fireClock > (hero == 1 ? 0.18 : 0.27) {
            let direction=normalized(fireInput)
            if hypot(direction.dx,direction.dy)>0.2 {
                fireClock=0
                shoot(from:player.node.position,direction:direction,enemy:false,damage:hero==2 ? 35 : 27)
            }
        }
        for i in enemies.indices {
            let enemy=enemies[i]
            let vector=CGVector(dx:player.node.position.x-enemy.node.position.x,
                                dy:player.node.position.y-enemy.node.position.y)
            let dir=normalized(vector)
            let d=distance(player.node.position,enemy.node.position)
            if d>85 { move(enemy.node,direction:dir,speed:enemy.speed,dt:dt,radius:20) }
            if d<39 {
                player.health=max(0,player.health-CGFloat(dt)*(12+CGFloat(difficulty)*6))
            }
        }
        if enemyShotClock>1.2 && !enemies.isEmpty {
            enemyShotClock=0
            for enemy in enemies.prefix(3) {
                let dir=CGVector(dx:player.node.position.x-enemy.node.position.x,
                                 dy:player.node.position.y-enemy.node.position.y)
                if distance(player.node.position,enemy.node.position)<320 {
                    shoot(from:enemy.node.position,direction:dir,enemy:true,damage:8+CGFloat(difficulty)*3)
                }
            }
        }
        for bullet in bullets.reversed() {
            guard let data=bullet.userData,
                  let vx=data["vx"] as? Double,
                  let vy=data["vy"] as? Double,
                  let damage=data["damage"] as? Double else { continue }
            bullet.position.x += CGFloat(vx)*dt
            bullet.position.y += CGFloat(vy)*dt
            var hit = abs(bullet.position.x)>490 || abs(bullet.position.y)>270 ||
                      !canOccupy(bullet.position,radius:7)
            if !hit && bullet.name=="heroBullet" {
                for i in enemies.indices.reversed() {
                    if distance(bullet.position,enemies[i].node.position)<27 {
                        enemies[i].health -= CGFloat(damage)
                        charge=min(1,charge+0.035)
                        hit=true
                        if enemies[i].health<=0 { defeatEnemy(at:i) }
                        break
                    }
                }
            } else if !hit && bullet.name=="enemyBullet" &&
                        distance(bullet.position,player.node.position)<28 {
                player.health=max(0,player.health-CGFloat(damage))
                hit=true
            }
            if hit { bullet.removeFromParent(); bullets.removeAll { $0===bullet } }
        }
        for pickup in pickups where distance(pickup.position,player.node.position)<38 {
            player.health=min(player.maxHealth,player.health+22)
            pickup.removeFromParent()
        }
        pickups.removeAll { $0.parent == nil }
        onState?(Int(player.health),score,charge)
    }
}
