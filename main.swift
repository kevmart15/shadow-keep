import AppKit
import SceneKit
import SpriteKit

// MARK: - Vector Math
extension SCNVector3 {
    static func + (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x+b.x, a.y+b.y, a.z+b.z) }
    static func - (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x-b.x, a.y-b.y, a.z-b.z) }
    static func * (v: SCNVector3, s: CGFloat) -> SCNVector3 { SCNVector3(v.x*s, v.y*s, v.z*s) }
    var len: CGFloat { sqrt(x*x + y*y + z*z) }
    var flat: CGFloat { sqrt(x*x + z*z) }
    var norm: SCNVector3 { let l = len; guard l > 0.001 else { return SCNVector3(0,0,0) }; return SCNVector3(x/l, y/l, z/l) }
    var flatNorm: SCNVector3 { let l = flat; guard l > 0.001 else { return SCNVector3(0,0,-1) }; return SCNVector3(x/l, 0, z/l) }
}
func lp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a+(b-a)*t }
func rF(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { CGFloat.random(in: lo...hi) }
func rI(_ lo: Int, _ hi: Int) -> Int { Int.random(in: lo...hi) }

// MARK: - Constants
let WIN_W: CGFloat = 1280
let WIN_H: CGFloat = 720
let TILE: CGFloat = 2.0
let GRID_W = 42
let GRID_H = 42
let P_SPEED: CGFloat = 9.0
let P_ATK_RANGE: CGFloat = 2.8
let P_ATK_ARC: CGFloat = CGFloat.pi * 0.7
let P_ATK_CD: CGFloat = 0.35
let P_DASH_DUR: CGFloat = 0.18
let P_DASH_CD: CGFloat = 0.55
let P_DASH_SPD: CGFloat = 28.0
let KNOCKBACK: CGFloat = 8.0

// MARK: - Colors
let cCyan = NSColor(red: 0, green: 0.85, blue: 1, alpha: 1)
let cRed = NSColor(red: 1, green: 0.15, blue: 0.1, alpha: 1)
let cGreen = NSColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1)
let cGold = NSColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
let cPurple = NSColor(red: 0.6, green: 0.15, blue: 0.9, alpha: 1)
let cOrange = NSColor(red: 1, green: 0.5, blue: 0.1, alpha: 1)
let cFloor = NSColor(red: 0.18, green: 0.16, blue: 0.14, alpha: 1)
let cFloor2 = NSColor(red: 0.15, green: 0.13, blue: 0.11, alpha: 1)
let cWall = NSColor(red: 0.28, green: 0.24, blue: 0.22, alpha: 1)
let cWallDk = NSColor(red: 0.2, green: 0.17, blue: 0.15, alpha: 1)

func mm(_ c: NSColor, e: NSColor? = nil, con: Bool = false) -> SCNMaterial {
    let m = SCNMaterial(); m.diffuse.contents = c
    if let em = e { m.emission.contents = em }
    if con { m.lightingModel = .constant }; return m
}

// MARK: - Room
struct Room { let x, y, w, h: Int; var cx: Int { x+w/2 }; var cy: Int { y+h/2 } }

// MARK: - Dungeon Generator
func generateDungeon(floor: Int) -> ([[Int]], [Room]) {
    var grid = Array(repeating: Array(repeating: 0, count: GRID_W), count: GRID_H)
    var rooms: [Room] = []
    let target = min(12, 6 + floor)
    for _ in 0..<target * 6 {
        if rooms.count >= target { break }
        let w = rI(5, 9), h = rI(5, 9)
        let x = rI(2, GRID_W - w - 2), y = rI(2, GRID_H - h - 2)
        var ok = true
        for r in rooms {
            if x < r.x+r.w+2 && x+w+2 > r.x && y < r.y+r.h+2 && y+h+2 > r.y { ok = false; break }
        }
        if !ok { continue }
        for ry in y..<y+h { for rx in x..<x+w { grid[ry][rx] = 1 } }
        rooms.append(Room(x: x, y: y, w: w, h: h))
    }
    // Connect adjacent rooms with corridors
    for i in 0..<rooms.count-1 {
        var cx = rooms[i].cx, cy = rooms[i].cy
        let tx = rooms[i+1].cx, ty = rooms[i+1].cy
        while cx != tx { grid[cy][cx] = 1; cx += cx < tx ? 1 : -1 }
        while cy != ty { grid[cy][cx] = 1; cy += cy < ty ? 1 : -1 }
        grid[cy][cx] = 1
    }
    // Widen corridors to 2 tiles for comfort
    let snap = grid
    for y in 1..<GRID_H-1 {
        for x in 1..<GRID_W-1 {
            if snap[y][x] == 1 {
                if grid[y+1][x] == 0 && snap[y-1][x] == 1 { grid[y+1][x] = 1 }
                if grid[y][x+1] == 0 && snap[y][x-1] == 1 { grid[y][x+1] = 1 }
            }
        }
    }
    return (grid, rooms)
}

// MARK: - Dungeon Renderer
func renderDungeon(grid: [[Int]]) -> SCNNode {
    let root = SCNNode()
    let floorGeo = SCNBox(width: TILE, height: 0.1, length: TILE, chamferRadius: 0)
    let wallGeo = SCNBox(width: TILE, height: 3.5, length: TILE, chamferRadius: 0)
    let floorMat1 = mm(cFloor); let floorMat2 = mm(cFloor2)
    let wallMat = mm(cWall); let wallTopMat = mm(cWallDk)
    wallGeo.materials = [wallMat, wallMat, wallTopMat, wallMat, wallMat, wallMat]
    for y in 0..<GRID_H {
        for x in 0..<GRID_W {
            let wx = CGFloat(x) * TILE
            let wz = CGFloat(y) * TILE
            if grid[y][x] == 1 {
                let f = SCNNode(geometry: floorGeo)
                f.geometry!.materials = [(x+y) % 2 == 0 ? floorMat1 : floorMat2]
                f.position = SCNVector3(wx, -0.05, wz)
                root.addChildNode(f)
            } else {
                // Only render walls adjacent to floor
                var adj = false
                for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)] {
                    let nx = x+dx, ny = y+dy
                    if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H && grid[ny][nx] == 1 { adj = true; break }
                }
                if adj {
                    let w = SCNNode(geometry: wallGeo)
                    w.position = SCNVector3(wx, 1.65, wz)
                    root.addChildNode(w)
                }
            }
        }
    }
    return root
}

// MARK: - Character Builders
func buildPlayer() -> SCNNode {
    let root = SCNNode()
    // Body
    let body = SCNNode(geometry: SCNCapsule(capRadius: 0.35, height: 1.2))
    body.geometry!.materials = [mm(NSColor(red: 0.25, green: 0.25, blue: 0.3, alpha: 1),
                                   e: NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1))]
    body.position = SCNVector3(0, 0.8, 0)
    root.addChildNode(body)
    // Head
    let head = SCNNode(geometry: SCNSphere(radius: 0.25))
    head.geometry!.materials = [mm(NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1))]
    head.position = SCNVector3(0, 1.65, 0)
    root.addChildNode(head)
    // Visor glow
    let visor = SCNNode(geometry: SCNBox(width: 0.3, height: 0.08, length: 0.1, chamferRadius: 0.02))
    visor.geometry!.materials = [mm(cCyan, e: cCyan, con: true)]
    visor.position = SCNVector3(0, 1.65, -0.22)
    root.addChildNode(visor)
    // Shoulder pads
    for s: CGFloat in [-1, 1] {
        let sh = SCNNode(geometry: SCNBox(width: 0.25, height: 0.15, length: 0.3, chamferRadius: 0.04))
        sh.geometry!.materials = [mm(NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1))]
        sh.position = SCNVector3(s * 0.45, 1.3, 0)
        root.addChildNode(sh)
    }
    // Sword pivot (child rotates for swing)
    let swordPivot = SCNNode(); swordPivot.name = "swordPivot"
    swordPivot.position = SCNVector3(0, 1.0, 0)
    root.addChildNode(swordPivot)
    // Sword
    let blade = SCNNode(geometry: SCNBox(width: 0.06, height: 0.06, length: 1.6, chamferRadius: 0.02))
    blade.geometry!.materials = [mm(NSColor(white: 0.7, alpha: 1), e: NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1))]
    blade.position = SCNVector3(0.4, 0, -1.0)
    swordPivot.addChildNode(blade)
    // Sword edge glow
    let edge = SCNNode(geometry: SCNBox(width: 0.02, height: 0.08, length: 1.4, chamferRadius: 0.01))
    edge.geometry!.materials = [mm(cCyan, e: cCyan, con: true)]
    edge.position = SCNVector3(0.4, 0, -1.0)
    swordPivot.addChildNode(edge)
    // Guard
    let guard_ = SCNNode(geometry: SCNBox(width: 0.3, height: 0.06, length: 0.06, chamferRadius: 0.02))
    guard_.geometry!.materials = [mm(cGold)]
    guard_.position = SCNVector3(0.4, 0, -0.2)
    swordPivot.addChildNode(guard_)
    return root
}

func buildEnemy(type: Int) -> SCNNode {
    let root = SCNNode()
    switch type {
    case 0: // Slime
        let body = SCNNode(geometry: SCNSphere(radius: 0.55))
        body.geometry!.materials = [mm(NSColor(red: 0.15, green: 0.6, blue: 0.15, alpha: 0.85),
                                       e: NSColor(red: 0.05, green: 0.2, blue: 0.05, alpha: 1))]
        body.position = SCNVector3(0, 0.45, 0)
        body.scale = SCNVector3(1, 0.7, 1)
        root.addChildNode(body)
        let eye1 = SCNNode(geometry: SCNSphere(radius: 0.08))
        eye1.geometry!.materials = [mm(.white, e: .white, con: true)]
        eye1.position = SCNVector3(-0.15, 0.55, -0.35); root.addChildNode(eye1)
        let eye2 = SCNNode(geometry: SCNSphere(radius: 0.08))
        eye2.geometry!.materials = [mm(.white, e: .white, con: true)]
        eye2.position = SCNVector3(0.15, 0.55, -0.35); root.addChildNode(eye2)
        // Idle squish animation
        let squish = SCNAction.sequence([
            SCNAction.scale(to: 0.9, duration: 0.5),
            SCNAction.scale(to: 1.1, duration: 0.5)])
        root.runAction(SCNAction.repeatForever(squish))
    case 1: // Skeleton
        let torso = SCNNode(geometry: SCNBox(width: 0.4, height: 0.7, length: 0.25, chamferRadius: 0.03))
        torso.geometry!.materials = [mm(NSColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1))]
        torso.position = SCNVector3(0, 0.9, 0); root.addChildNode(torso)
        let skull = SCNNode(geometry: SCNSphere(radius: 0.2))
        skull.geometry!.materials = [mm(NSColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1))]
        skull.position = SCNVector3(0, 1.4, 0); root.addChildNode(skull)
        // Glowing eyes
        for s: CGFloat in [-1, 1] {
            let e = SCNNode(geometry: SCNSphere(radius: 0.04))
            e.geometry!.materials = [mm(cRed, e: cRed, con: true)]
            e.position = SCNVector3(s*0.08, 1.42, -0.16); root.addChildNode(e)
        }
        // Legs
        for s: CGFloat in [-1, 1] {
            let l = SCNNode(geometry: SCNCylinder(radius: 0.06, height: 0.5))
            l.geometry!.materials = [mm(NSColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1))]
            l.position = SCNVector3(s*0.12, 0.3, 0); root.addChildNode(l)
        }
        // Sword
        let sw = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 1.1, chamferRadius: 0.01))
        sw.geometry!.materials = [mm(NSColor(white: 0.6, alpha: 1))]
        sw.position = SCNVector3(0.35, 0.9, -0.5); root.addChildNode(sw)
    default: // Mage
        let robe = SCNNode(geometry: SCNCone(topRadius: 0.15, bottomRadius: 0.45, height: 1.3))
        robe.geometry!.materials = [mm(NSColor(red: 0.25, green: 0.1, blue: 0.35, alpha: 1),
                                       e: NSColor(red: 0.08, green: 0, blue: 0.12, alpha: 1))]
        robe.position = SCNVector3(0, 0.65, 0); root.addChildNode(robe)
        let head = SCNNode(geometry: SCNSphere(radius: 0.18))
        head.geometry!.materials = [mm(NSColor(red: 0.15, green: 0.05, blue: 0.2, alpha: 1))]
        head.position = SCNVector3(0, 1.45, 0); root.addChildNode(head)
        // Glowing eyes
        for s: CGFloat in [-1, 1] {
            let e = SCNNode(geometry: SCNSphere(radius: 0.04))
            e.geometry!.materials = [mm(cPurple, e: cPurple, con: true)]
            e.position = SCNVector3(s*0.07, 1.48, -0.14); root.addChildNode(e)
        }
        // Hat
        let hat = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.22, height: 0.5))
        hat.geometry!.materials = [mm(NSColor(red: 0.2, green: 0.08, blue: 0.3, alpha: 1))]
        hat.position = SCNVector3(0, 1.8, 0); root.addChildNode(hat)
        // Floating orb
        let orb = SCNNode(geometry: SCNSphere(radius: 0.12))
        orb.geometry!.materials = [mm(cPurple, e: cPurple, con: true)]
        orb.position = SCNVector3(0.4, 1.3, -0.3); orb.name = "orb"
        orb.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.8),
            SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.8)])))
        root.addChildNode(orb)
    }
    return root
}

// MARK: - Item Builders
func buildPotion() -> SCNNode {
    let n = SCNNode()
    let body = SCNNode(geometry: SCNCylinder(radius: 0.15, height: 0.3))
    body.geometry!.materials = [mm(NSColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.8), e: cRed)]
    body.position = SCNVector3(0, 0.25, 0); n.addChildNode(body)
    let top = SCNNode(geometry: SCNSphere(radius: 0.12))
    top.geometry!.materials = [mm(cRed, e: cRed, con: true)]
    top.position = SCNVector3(0, 0.45, 0); n.addChildNode(top)
    n.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 3)))
    n.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.moveBy(x: 0, y: 0.15, z: 0, duration: 0.6),
        SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.6)])))
    return n
}

func buildKey() -> SCNNode {
    let n = SCNNode()
    let shaft = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 0.6, chamferRadius: 0.02))
    shaft.geometry!.materials = [mm(cGold, e: cGold, con: true)]
    shaft.position = SCNVector3(0, 0.5, 0); shaft.eulerAngles.x = CGFloat.pi / 2
    n.addChildNode(shaft)
    let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.15, pipeRadius: 0.04))
    ring.geometry!.materials = [mm(cGold, e: cGold, con: true)]
    ring.position = SCNVector3(0, 0.85, 0)
    n.addChildNode(ring)
    n.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 2.5)))
    n.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.moveBy(x: 0, y: 0.2, z: 0, duration: 0.7),
        SCNAction.moveBy(x: 0, y: -0.2, z: 0, duration: 0.7)])))
    return n
}

func buildStairs() -> SCNNode {
    let n = SCNNode()
    for i in 0..<4 {
        let step = SCNNode(geometry: SCNBox(width: 1.5, height: 0.25, length: 0.5, chamferRadius: 0.02))
        step.geometry!.materials = [mm(NSColor(red: 0.35, green: 0.3, blue: 0.25, alpha: 1))]
        step.position = SCNVector3(0, CGFloat(i) * 0.25, CGFloat(i) * 0.4 - 0.6)
        n.addChildNode(step)
    }
    // Glow at bottom
    let glow = SCNNode(geometry: SCNSphere(radius: 0.3))
    glow.geometry!.materials = [mm(cGold, e: cGold, con: true)]
    glow.position = SCNVector3(0, 0.3, -1.0)
    glow.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.fadeOpacity(to: 0.4, duration: 0.8),
        SCNAction.fadeOpacity(to: 1.0, duration: 0.8)])))
    n.addChildNode(glow)
    return n
}

func buildTorch() -> SCNNode {
    let n = SCNNode()
    let stick = SCNNode(geometry: SCNCylinder(radius: 0.04, height: 0.6))
    stick.geometry!.materials = [mm(NSColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))]
    stick.position = SCNVector3(0, 1.8, 0); n.addChildNode(stick)
    let flame = SCNNode(geometry: SCNSphere(radius: 0.1))
    flame.geometry!.materials = [mm(cOrange, e: cOrange, con: true)]
    flame.position = SCNVector3(0, 2.15, 0); n.addChildNode(flame)
    flame.runAction(SCNAction.repeatForever(SCNAction.sequence([
        SCNAction.scale(to: 1.3, duration: 0.2), SCNAction.scale(to: 0.8, duration: 0.3)])))
    let light = SCNNode(); light.light = SCNLight()
    light.light!.type = .omni
    light.light!.color = NSColor(red: 1, green: 0.7, blue: 0.3, alpha: 1)
    light.light!.intensity = 200
    light.light!.attenuationStartDistance = 2; light.light!.attenuationEndDistance = 10
    light.position = SCNVector3(0, 2.2, 0); n.addChildNode(light)
    return n
}

// MARK: - Projectile (mage fireball)
func buildFireball() -> SCNNode {
    let n = SCNNode(geometry: SCNSphere(radius: 0.18))
    n.geometry!.materials = [mm(cPurple, e: cPurple, con: true)]
    let ps = SCNParticleSystem(); ps.birthRate = 60; ps.particleLifeSpan = 0.3
    ps.particleSize = 0.08; ps.particleColor = cPurple; ps.blendMode = .additive
    ps.emitterShape = SCNSphere(radius: 0.05); ps.particleVelocity = 2
    ps.spreadingAngle = 180; ps.isAffectedByGravity = false
    n.addParticleSystem(ps)
    return n
}

// MARK: - Explosion
func makeHitPS(color: NSColor) -> SCNParticleSystem {
    let ps = SCNParticleSystem(); ps.birthRate = 200; ps.particleLifeSpan = 0.4
    ps.emissionDuration = 0.05; ps.loops = false; ps.particleSize = 0.1
    ps.particleColor = color; ps.blendMode = .additive
    ps.emitterShape = SCNSphere(radius: 0.2); ps.particleVelocity = 8
    ps.spreadingAngle = 180; ps.isAffectedByGravity = false
    return ps
}

// MARK: - Data Types
struct EnemyData {
    let node: SCNNode; var type: Int; var hp: Int; var maxHp: Int
    var radius: CGFloat; var speed: CGFloat; var damage: Int
    var atkRange: CGFloat; var atkCD: CGFloat; var shootCD: CGFloat
    var knockVel: SCNVector3; var state: Int // 0=idle 1=chase 2=attack 3=hurt
    var hurtT: CGFloat; var seenPlayer: Bool
}
struct ProjData { let node: SCNNode; var vel: SCNVector3; var life: CGFloat; var damage: Int }
struct ItemData { let node: SCNNode; var type: Int; var gx: Int; var gy: Int } // 0=potion 1=key

// MARK: - GameView
class GameView: SCNView {
    var heldKeys: Set<UInt16> = []
    var pressedKeys: Set<UInt16> = []
    override var acceptsFirstResponder: Bool { true }
    override func performKeyEquivalent(with event: NSEvent) -> Bool { false }
    override func keyDown(with event: NSEvent) {
        heldKeys.insert(event.keyCode)
        if !event.isARepeat { pressedKeys.insert(event.keyCode) }
    }
    override func keyUp(with event: NSEvent) { heldKeys.remove(event.keyCode) }
    override func mouseDown(with event: NSEvent) { pressedKeys.insert(999) }
    func consume() -> Set<UInt16> { let p = pressedKeys; pressedKeys.removeAll(); return p }
}

// MARK: - GameController
class GameController: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    var view: GameView!
    var playerNode: SCNNode!
    var cameraNode: SCNNode!
    var gameNode: SCNNode!
    var hudScene: SKScene!
    var dungeonNode: SCNNode!

    // HUD
    var hpBar: SKShapeNode!; var hpBG: SKShapeNode!
    var floorLabel: SKLabelNode!; var scoreLabel: SKLabelNode!
    var keyIcon: SKNode!; var msgLabel: SKLabelNode!
    var menuNode: SKNode?; var deathNode: SKNode?; var upgradeNode: SKNode?
    // Minimap
    var mapNode: SKNode!; var mapFloor: SKShapeNode!; var mapPlayer: SKShapeNode!
    var mapEnemyDots: [SKShapeNode] = []

    var grid: [[Int]] = []; var rooms: [Room] = []
    var explored: [[Bool]] = []
    var enemies: [EnemyData] = []
    var projectiles: [ProjData] = []
    var items: [ItemData] = []
    var stairsNode: SCNNode?; var stairsRoom = -1

    var state = "menu"
    var lastTime: TimeInterval = 0
    var floorNum = 1; var score = 0
    var pHP = 100; var pMaxHP = 100; var pDmg = 22; var pSpdMult: CGFloat = 1
    var pAtkMult: CGFloat = 1; var pLifesteal: CGFloat = 0
    var pFacing = SCNVector3(0, 0, -1)
    var pAtkCD: CGFloat = 0; var pDashT: CGFloat = 0; var pDashCD: CGFloat = 0
    var pDashDir = SCNVector3(0, 0, -1)
    var pInv: CGFloat = 0; var hasKey = false
    var shakeAmt: CGFloat = 0; var hitPause: CGFloat = 0
    var killCount = 0

    func setup(_ v: GameView) {
        view = v; view.scene = scene; view.delegate = self
        view.isPlaying = true; view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling4X; view.backgroundColor = .black
        scene.background.contents = NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        setupLighting(); setupCamera(); setupHUD(); showMenu()
    }

    func setupLighting() {
        let amb = SCNNode(); amb.light = SCNLight()
        amb.light!.type = .ambient; amb.light!.color = NSColor(white: 0.06, alpha: 1)
        scene.rootNode.addChildNode(amb)
        let dir = SCNNode(); dir.light = SCNLight()
        dir.light!.type = .directional; dir.light!.color = NSColor(white: 0.15, alpha: 1)
        dir.eulerAngles = SCNVector3(-0.8, 0.3, 0)
        scene.rootNode.addChildNode(dir)
    }

    func setupCamera() {
        cameraNode = SCNNode(); cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 200; cameraNode.camera!.fieldOfView = 55
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 1.0; cameraNode.camera!.bloomThreshold = 0.3
        cameraNode.camera!.bloomBlurRadius = 10
        cameraNode.camera!.vignettingIntensity = 0.8; cameraNode.camera!.vignettingPower = 1.5
        cameraNode.position = SCNVector3(0, 22, 14)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    func setupHUD() {
        hudScene = SKScene(size: CGSize(width: WIN_W, height: WIN_H))
        hudScene.backgroundColor = .clear

        hpBG = SKShapeNode(rect: CGRect(x: 30, y: WIN_H-45, width: 220, height: 16), cornerRadius: 3)
        hpBG.fillColor = NSColor(white: 0.1, alpha: 0.8)
        hpBG.strokeColor = NSColor(white: 0.3, alpha: 0.5); hpBG.lineWidth = 1; hpBG.zPosition = 10
        hudScene.addChild(hpBG)
        hpBar = SKShapeNode(rect: CGRect(x: 30, y: WIN_H-45, width: 220, height: 16), cornerRadius: 3)
        hpBar.fillColor = cGreen; hpBar.strokeColor = .clear; hpBar.zPosition = 11
        hudScene.addChild(hpBar)
        let hpLbl = SKLabelNode(text: "HP"); hpLbl.fontName = "Menlo"; hpLbl.fontSize = 9
        hpLbl.fontColor = NSColor(white: 0.5, alpha: 1); hpLbl.horizontalAlignmentMode = .left
        hpLbl.position = CGPoint(x: 30, y: WIN_H-60); hpLbl.zPosition = 10; hudScene.addChild(hpLbl)

        floorLabel = SKLabelNode(text: "FLOOR 1"); floorLabel.fontName = "Menlo-Bold"
        floorLabel.fontSize = 16; floorLabel.fontColor = cGold
        floorLabel.position = CGPoint(x: WIN_W/2, y: WIN_H-35); floorLabel.zPosition = 10
        hudScene.addChild(floorLabel)

        scoreLabel = SKLabelNode(text: "0"); scoreLabel.fontName = "Menlo-Bold"
        scoreLabel.fontSize = 18; scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: WIN_W-30, y: WIN_H-35); scoreLabel.zPosition = 10
        hudScene.addChild(scoreLabel)

        keyIcon = SKNode(); keyIcon.position = CGPoint(x: WIN_W/2, y: 40); keyIcon.zPosition = 10
        let kBg = SKShapeNode(rect: CGRect(x: -60, y: -12, width: 120, height: 24), cornerRadius: 5)
        kBg.fillColor = NSColor(red: 0.1, green: 0.08, blue: 0.02, alpha: 0.8)
        kBg.strokeColor = cGold; kBg.lineWidth = 1; keyIcon.addChild(kBg)
        let kLbl = SKLabelNode(text: "KEY FOUND"); kLbl.fontName = "Menlo-Bold"; kLbl.fontSize = 12
        kLbl.fontColor = cGold; kLbl.verticalAlignmentMode = .center; keyIcon.addChild(kLbl)
        keyIcon.isHidden = true; hudScene.addChild(keyIcon)

        msgLabel = SKLabelNode(text: ""); msgLabel.fontName = "Menlo-Bold"; msgLabel.fontSize = 18
        msgLabel.fontColor = .white; msgLabel.position = CGPoint(x: WIN_W/2, y: WIN_H/2 + 60)
        msgLabel.zPosition = 30; hudScene.addChild(msgLabel)

        // Minimap
        mapNode = SKNode(); mapNode.position = CGPoint(x: WIN_W - 125, y: 15); mapNode.zPosition = 10
        let mapBG = SKShapeNode(rect: CGRect(x: -5, y: -5, width: 110, height: 110), cornerRadius: 4)
        mapBG.fillColor = NSColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 0.75)
        mapBG.strokeColor = NSColor(white: 0.2, alpha: 0.5); mapBG.lineWidth = 1
        mapNode.addChild(mapBG)
        mapFloor = SKShapeNode(); mapFloor.fillColor = NSColor(white: 0.25, alpha: 0.7)
        mapFloor.strokeColor = .clear; mapNode.addChild(mapFloor)
        mapPlayer = SKShapeNode(circleOfRadius: 3)
        mapPlayer.fillColor = cCyan; mapPlayer.strokeColor = .clear; mapPlayer.zPosition = 5
        mapNode.addChild(mapPlayer)
        hudScene.addChild(mapNode)

        view.overlaySKScene = hudScene
    }

    // MARK: - Menu
    func showMenu() {
        state = "menu"
        deathNode?.removeFromParent(); deathNode = nil
        upgradeNode?.removeFromParent(); upgradeNode = nil
        gameNode?.removeFromParentNode(); gameNode = nil

        let mn = SKNode(); mn.zPosition = 50
        let t = SKLabelNode(text: "SHADOW KEEP"); t.fontName = "Menlo-Bold"; t.fontSize = 52
        t.fontColor = cCyan; t.position = CGPoint(x: WIN_W/2, y: WIN_H*0.62); mn.addChild(t)
        let sub = SKLabelNode(text: "3D DUNGEON CRAWLER"); sub.fontName = "Menlo"; sub.fontSize = 13
        sub.fontColor = NSColor(white: 0.4, alpha: 1)
        sub.position = CGPoint(x: WIN_W/2, y: WIN_H*0.55); mn.addChild(sub)
        let s = SKLabelNode(text: "[ PRESS SPACE TO DESCEND ]"); s.fontName = "Menlo"; s.fontSize = 16
        s.fontColor = NSColor(white: 0.6, alpha: 1); s.position = CGPoint(x: WIN_W/2, y: WIN_H*0.36)
        s.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.8), SKAction.fadeAlpha(to: 0.9, duration: 0.8)])))
        mn.addChild(s)
        let c = SKLabelNode(text: "WASD: Move   Click: Attack   Space: Dash   E: Interact")
        c.fontName = "Menlo"; c.fontSize = 11; c.fontColor = NSColor(white: 0.3, alpha: 1)
        c.position = CGPoint(x: WIN_W/2, y: WIN_H*0.27); mn.addChild(c)
        hudScene.addChild(mn); menuNode = mn
        setHUDVisible(false)
    }

    func setHUDVisible(_ v: Bool) {
        hpBar.isHidden = !v; hpBG.isHidden = !v; floorLabel.isHidden = !v
        scoreLabel.isHidden = !v; mapNode.isHidden = !v
    }

    // MARK: - Start Game
    func startGame() {
        menuNode?.removeFromParent(); menuNode = nil
        deathNode?.removeFromParent(); deathNode = nil
        floorNum = 1; score = 0; pHP = 100; pMaxHP = 100; pDmg = 22
        pSpdMult = 1; pAtkMult = 1; pLifesteal = 0; killCount = 0
        setHUDVisible(true); generateFloor()
    }

    func generateFloor() {
        upgradeNode?.removeFromParent(); upgradeNode = nil
        gameNode?.removeFromParentNode()
        gameNode = SCNNode(); scene.rootNode.addChildNode(gameNode)
        enemies = []; projectiles = []; items = []; hasKey = false; keyIcon.isHidden = true

        let result = generateDungeon(floor: floorNum)
        grid = result.0; rooms = result.1
        explored = Array(repeating: Array(repeating: false, count: GRID_W), count: GRID_H)

        // Render dungeon
        dungeonNode = renderDungeon(grid: grid)
        gameNode.addChildNode(dungeonNode)

        // Player
        playerNode = buildPlayer()
        let spawn = rooms[0]
        playerNode.position = SCNVector3(CGFloat(spawn.cx) * TILE, 0, CGFloat(spawn.cy) * TILE)
        gameNode.addChildNode(playerNode)
        exploreAround(playerNode.position)

        // Player light
        let pLight = SCNNode(); pLight.light = SCNLight()
        pLight.light!.type = .omni
        pLight.light!.color = NSColor(red: 0.35, green: 0.35, blue: 0.5, alpha: 1)
        pLight.light!.intensity = 500
        pLight.light!.attenuationStartDistance = 3; pLight.light!.attenuationEndDistance = 14
        pLight.position = SCNVector3(0, 4, 0); playerNode.addChildNode(pLight)

        // Stairs in farthest room
        var maxDist: CGFloat = 0; stairsRoom = rooms.count - 1
        for i in 1..<rooms.count {
            let d = CGFloat(abs(rooms[i].cx - spawn.cx) + abs(rooms[i].cy - spawn.cy))
            if d > maxDist { maxDist = d; stairsRoom = i }
        }
        stairsNode = buildStairs()
        stairsNode!.position = SCNVector3(CGFloat(rooms[stairsRoom].cx) * TILE, 0,
                                           CGFloat(rooms[stairsRoom].cy) * TILE)
        gameNode.addChildNode(stairsNode!)

        // Key in a different room
        let keyRoom = rooms.count > 2 ? rI(1, rooms.count - 1) : (rooms.count > 1 ? 1 : 0)
        let kn = buildKey()
        kn.position = SCNVector3(CGFloat(rooms[keyRoom].cx) * TILE, 0, CGFloat(rooms[keyRoom].cy) * TILE)
        gameNode.addChildNode(kn)
        items.append(ItemData(node: kn, type: 1, gx: rooms[keyRoom].cx, gy: rooms[keyRoom].cy))

        // Potions (1-2)
        for _ in 0..<rI(1, 2) {
            let ri = rI(1, rooms.count - 1)
            let pn = buildPotion()
            let px = rI(rooms[ri].x + 1, rooms[ri].x + rooms[ri].w - 2)
            let py = rI(rooms[ri].y + 1, rooms[ri].y + rooms[ri].h - 2)
            pn.position = SCNVector3(CGFloat(px) * TILE, 0, CGFloat(py) * TILE)
            gameNode.addChildNode(pn)
            items.append(ItemData(node: pn, type: 0, gx: px, gy: py))
        }

        // Torches
        for room in rooms {
            let torchCount = rI(1, 2)
            for _ in 0..<torchCount {
                let edge = rI(0, 3)
                var tx = 0; var ty = 0
                switch edge {
                case 0: tx = room.x; ty = rI(room.y, room.y + room.h - 1)
                case 1: tx = room.x + room.w - 1; ty = rI(room.y, room.y + room.h - 1)
                case 2: tx = rI(room.x, room.x + room.w - 1); ty = room.y
                default: tx = rI(room.x, room.x + room.w - 1); ty = room.y + room.h - 1
                }
                let tn = buildTorch()
                tn.position = SCNVector3(CGFloat(tx) * TILE, 0, CGFloat(ty) * TILE)
                gameNode.addChildNode(tn)
            }
        }

        // Enemies
        let baseEnemies = 2 + floorNum
        for i in 1..<rooms.count {
            let count = rI(max(1, baseEnemies - 1), baseEnemies + 1)
            for _ in 0..<count {
                let types: [Int]
                if floorNum <= 2 { types = [0, 0, 0, 1] }
                else if floorNum <= 4 { types = [0, 0, 1, 1, 2] }
                else { types = [0, 1, 1, 2, 2] }
                let t = types[rI(0, types.count - 1)]
                let en = buildEnemy(type: t)
                let ex = rI(rooms[i].x + 1, rooms[i].x + rooms[i].w - 2)
                let ey = rI(rooms[i].y + 1, rooms[i].y + rooms[i].h - 2)
                en.position = SCNVector3(CGFloat(ex) * TILE, 0, CGFloat(ey) * TILE)
                gameNode.addChildNode(en)
                let hp = t == 0 ? 40 + floorNum * 5 : (t == 1 ? 60 + floorNum * 8 : 50 + floorNum * 6)
                let spd: CGFloat = t == 0 ? 3.5 : (t == 1 ? 5.0 : 2.5)
                let dmg = t == 0 ? 8 + floorNum * 2 : (t == 1 ? 12 + floorNum * 2 : 18 + floorNum * 3)
                let ar: CGFloat = t == 0 ? 1.5 : (t == 1 ? 2.2 : 12.0)
                enemies.append(EnemyData(node: en, type: t, hp: hp, maxHp: hp,
                    radius: t == 2 ? 0.5 : 0.6, speed: spd, damage: dmg,
                    atkRange: ar, atkCD: 0, shootCD: t == 2 ? 2.0 : 0,
                    knockVel: SCNVector3(0,0,0), state: 0, hurtT: 0, seenPlayer: false))
            }
        }

        pAtkCD = 0; pDashT = 0; pDashCD = 0; pInv = 0; lastTime = 0
        floorLabel.text = "FLOOR \(floorNum)"
        state = "playing"
        showMessage("FLOOR \(floorNum)", duration: 1.5)
    }

    func showMessage(_ text: String, duration: Double = 2.0) {
        msgLabel.text = text; msgLabel.alpha = 1
        msgLabel.removeAllActions()
        msgLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: duration), SKAction.fadeOut(withDuration: 0.5)]))
    }

    // MARK: - Exploration
    func exploreAround(_ pos: SCNVector3) {
        let gx = Int(round(pos.x / TILE)); let gy = Int(round(pos.z / TILE))
        let radius = 6
        for dy in -radius...radius {
            for dx in -radius...radius {
                let nx = gx + dx, ny = gy + dy
                if nx >= 0 && nx < GRID_W && ny >= 0 && ny < GRID_H { explored[ny][nx] = true }
            }
        }
    }

    // MARK: - Tile collision
    func canWalk(_ wx: CGFloat, _ wz: CGFloat) -> Bool {
        let gx = Int(round(wx / TILE)); let gy = Int(round(wz / TILE))
        guard gx >= 0 && gx < GRID_W && gy >= 0 && gy < GRID_H else { return false }
        return grid[gy][gx] == 1
    }

    // MARK: - Render Loop
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if lastTime == 0 { lastTime = time; return }
        let dt = CGFloat(time - lastTime); lastTime = time
        if dt > 0.1 { return }
        if hitPause > 0 { hitPause -= dt; return }
        let pressed = view.consume()

        switch state {
        case "menu":
            if pressed.contains(49) { startGame() }
        case "playing":
            updatePlaying(dt, pressed: pressed)
        case "dead":
            if pressed.contains(49) { showMenu() }
        case "upgrading":
            if pressed.contains(18) { applyUpgrade(0) }
            else if pressed.contains(19) { applyUpgrade(1) }
            else if pressed.contains(20) { applyUpgrade(2) }
        default: break
        }
    }

    // MARK: - Main Update
    func updatePlaying(_ dt: CGFloat, pressed: Set<UInt16>) {
        let keys = view.heldKeys
        var dx: CGFloat = 0, dz: CGFloat = 0
        if keys.contains(0) || keys.contains(123) { dx -= 1 }
        if keys.contains(2) || keys.contains(124) { dx += 1 }
        if keys.contains(13) || keys.contains(126) { dz -= 1 }
        if keys.contains(1) || keys.contains(125) { dz += 1 }

        // Normalize diagonal
        if dx != 0 && dz != 0 { let n: CGFloat = 0.707; dx *= n; dz *= n }

        // Dash
        pDashCD -= dt
        if pressed.contains(49) && pDashCD <= 0 && (dx != 0 || dz != 0 || pFacing.flat > 0.1) {
            pDashT = P_DASH_DUR; pDashCD = P_DASH_CD
            pDashDir = (dx != 0 || dz != 0) ? SCNVector3(dx, 0, dz).flatNorm : pFacing.flatNorm
        }

        let speed: CGFloat
        if pDashT > 0 {
            pDashT -= dt; speed = P_DASH_SPD; dx = pDashDir.x; dz = pDashDir.z
            pInv = 0.1 // invincible during dash
        } else {
            speed = P_SPEED * pSpdMult
        }

        // Apply movement with collision
        if dx != 0 || dz != 0 {
            let newX = playerNode.position.x + dx * speed * dt
            let newZ = playerNode.position.z + dz * speed * dt
            // Check X and Z independently for sliding along walls
            if canWalk(newX, playerNode.position.z) { playerNode.position.x = newX }
            if canWalk(playerNode.position.x, newZ) { playerNode.position.z = newZ }

            if pDashT <= 0 {
                pFacing = SCNVector3(dx, 0, dz).flatNorm
                playerNode.eulerAngles.y = atan2(-pFacing.x, -pFacing.z)
            }
        }

        exploreAround(playerNode.position)

        // Attack
        pAtkCD -= dt
        if pressed.contains(999) && pAtkCD <= 0 { playerAttack() }

        // Invincibility
        if pInv > 0 {
            pInv -= dt
            playerNode.opacity = (Int(pInv * 15) % 2 == 0) ? 0.4 : 1.0
        } else { playerNode.opacity = 1.0 }

        // Camera follow
        let camTarget = playerNode.position + SCNVector3(0, 22, 14)
        cameraNode.position = SCNVector3(lp(cameraNode.position.x, camTarget.x, 0.08),
                                          lp(cameraNode.position.y, camTarget.y, 0.08),
                                          lp(cameraNode.position.z, camTarget.z, 0.08))
        cameraNode.look(at: playerNode.position)

        if shakeAmt > 0.03 {
            cameraNode.position.x += rF(-shakeAmt, shakeAmt)
            cameraNode.position.z += rF(-shakeAmt, shakeAmt)
            shakeAmt *= 0.85
        } else { shakeAmt = 0 }

        updateEnemies(dt)
        updateProjectiles(dt)
        checkItems()
        checkStairs(pressed)
        updateHUD()
        updateMinimap()
    }

    // MARK: - Player Attack
    func playerAttack() {
        pAtkCD = P_ATK_CD / pAtkMult

        // Sword swing animation
        if let pivot = playerNode.childNode(withName: "swordPivot", recursively: true) {
            pivot.removeAllActions()
            pivot.eulerAngles.y = CGFloat.pi * 0.4
            pivot.runAction(SCNAction.sequence([
                SCNAction.rotateTo(x: 0, y: -CGFloat.pi * 0.4, z: 0, duration: Double(P_ATK_CD * 0.6)),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.1)
            ]))
        }

        let facingAngle = atan2(-pFacing.x, -pFacing.z)
        var hitAny = false
        for i in (0..<enemies.count).reversed() {
            let toE = enemies[i].node.position - playerNode.position
            let dist = toE.flat
            if dist > P_ATK_RANGE { continue }
            let angleToE = atan2(-toE.x, -toE.z)
            var diff = facingAngle - angleToE
            while diff > CGFloat.pi { diff -= 2 * CGFloat.pi }
            while diff < -CGFloat.pi { diff += 2 * CGFloat.pi }
            if abs(diff) > P_ATK_ARC / 2 { continue }

            // Hit!
            let dmg = pDmg + rI(-2, 3)
            enemies[i].hp -= dmg
            let kb = toE.flatNorm * KNOCKBACK
            enemies[i].knockVel = kb
            enemies[i].state = 3; enemies[i].hurtT = 0.2

            // Flash
            enemies[i].node.runAction(SCNAction.sequence([
                SCNAction.fadeOpacity(to: 0.2, duration: 0.04),
                SCNAction.fadeOpacity(to: 1.0, duration: 0.04)]))

            // Damage number
            spawnDmgNum(at: enemies[i].node.position, amount: dmg, color: .white)
            hitAny = true

            // Lifesteal
            if pLifesteal > 0 { pHP = min(pMaxHP, pHP + Int(CGFloat(dmg) * pLifesteal)) }

            if enemies[i].hp <= 0 {
                // Death
                let pts = enemies[i].type == 0 ? 25 : (enemies[i].type == 1 ? 50 : 75)
                score += pts; killCount += 1
                let hitNode = SCNNode(); hitNode.position = enemies[i].node.position
                hitNode.addParticleSystem(makeHitPS(color: enemies[i].type == 0 ? cGreen :
                    (enemies[i].type == 1 ? cOrange : cPurple)))
                gameNode.addChildNode(hitNode)
                hitNode.runAction(SCNAction.sequence([SCNAction.wait(duration: 1), SCNAction.removeFromParentNode()]))
                enemies[i].node.removeFromParentNode(); enemies.remove(at: i)
            } else {
                let hitNode = SCNNode(); hitNode.position = enemies[i].node.position
                hitNode.addParticleSystem(makeHitPS(color: .white))
                gameNode.addChildNode(hitNode)
                hitNode.runAction(SCNAction.sequence([SCNAction.wait(duration: 0.8), SCNAction.removeFromParentNode()]))
            }
        }
        if hitAny { shakeAmt = 0.4; hitPause = 0.04 }
    }

    func spawnDmgNum(at pos: SCNVector3, amount: Int, color: NSColor) {
        let projected = view.projectPoint(pos + SCNVector3(rF(-0.3, 0.3), 2, 0))
        let sp = CGPoint(x: CGFloat(projected.x), y: WIN_H - CGFloat(projected.y))
        let lbl = SKLabelNode(text: "\(amount)"); lbl.fontName = "Menlo-Bold"; lbl.fontSize = 18
        lbl.fontColor = color; lbl.position = sp; lbl.zPosition = 40; hudScene.addChild(lbl)
        lbl.run(SKAction.sequence([
            SKAction.group([SKAction.moveBy(x: rF(-15, 15), y: 35, duration: 0.7),
                            SKAction.fadeOut(withDuration: 0.7)]),
            SKAction.removeFromParent()]))
    }

    // MARK: - Enemy AI
    func updateEnemies(_ dt: CGFloat) {
        let pp = playerNode.position
        for i in 0..<enemies.count {
            let pos = enemies[i].node.position
            let toP = pp - pos; let dist = toP.flat
            enemies[i].atkCD -= dt

            // Knockback
            if enemies[i].knockVel.flat > 0.5 {
                let kbMove = enemies[i].knockVel * dt
                let nx = pos.x + kbMove.x; let nz = pos.z + kbMove.z
                if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, 0, nz) }
                enemies[i].knockVel = enemies[i].knockVel * 0.85
            }

            // Hurt state
            if enemies[i].state == 3 {
                enemies[i].hurtT -= dt
                if enemies[i].hurtT <= 0 { enemies[i].state = 1 }
                continue
            }

            // Detection
            if dist < 12 { enemies[i].seenPlayer = true }
            if !enemies[i].seenPlayer { continue }

            enemies[i].node.look(at: SCNVector3(pp.x, 0, pp.z))

            switch enemies[i].type {
            case 0: // Slime - chase and bump
                if dist > enemies[i].atkRange {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, 0, nz) }
                } else if enemies[i].atkCD <= 0 {
                    if pInv <= 0 { playerTakeDamage(enemies[i].damage, from: pos) }
                    enemies[i].atkCD = 1.0
                }
            case 1: // Skeleton - chase, melee
                if dist > enemies[i].atkRange {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, 0, nz) }
                } else if enemies[i].atkCD <= 0 {
                    if pInv <= 0 { playerTakeDamage(enemies[i].damage, from: pos) }
                    enemies[i].atkCD = 0.8
                }
            default: // Mage - keep distance, shoot
                if dist < 5 {
                    let away = (pos - pp).flatNorm
                    let nx = pos.x + away.x * enemies[i].speed * dt
                    let nz = pos.z + away.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, 0, nz) }
                } else if dist > 14 {
                    let dir = toP.flatNorm
                    let nx = pos.x + dir.x * enemies[i].speed * dt
                    let nz = pos.z + dir.z * enemies[i].speed * dt
                    if canWalk(nx, nz) { enemies[i].node.position = SCNVector3(nx, 0, nz) }
                }
                enemies[i].shootCD -= dt
                if enemies[i].shootCD <= 0 && dist < 15 {
                    let fb = buildFireball()
                    fb.position = pos + SCNVector3(0, 1.3, 0)
                    let dir = (pp + SCNVector3(0, 0.8, 0) - fb.position).norm
                    projectiles.append(ProjData(node: fb, vel: dir * 10, life: 4, damage: enemies[i].damage))
                    gameNode.addChildNode(fb)
                    enemies[i].shootCD = max(1.2, 2.5 - CGFloat(floorNum) * 0.1)
                }
            }
            enemies[i].state = 1
        }
    }

    func updateProjectiles(_ dt: CGFloat) {
        for i in (0..<projectiles.count).reversed() {
            projectiles[i].life -= dt
            projectiles[i].node.position = projectiles[i].node.position + projectiles[i].vel * dt
            // Hit player
            let dist = (projectiles[i].node.position - playerNode.position).flat
            if dist < 1.0 && pInv <= 0 {
                playerTakeDamage(projectiles[i].damage, from: projectiles[i].node.position)
                projectiles[i].node.removeFromParentNode(); projectiles.remove(at: i); continue
            }
            // Wall collision
            if !canWalk(projectiles[i].node.position.x, projectiles[i].node.position.z) {
                projectiles[i].node.removeFromParentNode(); projectiles.remove(at: i); continue
            }
            if projectiles[i].life <= 0 {
                projectiles[i].node.removeFromParentNode(); projectiles.remove(at: i)
            }
        }
    }

    func playerTakeDamage(_ amount: Int, from pos: SCNVector3) {
        if pInv > 0 { return }
        pHP -= amount; pInv = 0.6; shakeAmt = 1.0
        spawnDmgNum(at: playerNode.position, amount: amount, color: cRed)
        if pHP <= 0 { pHP = 0; gameOver() }
    }

    func gameOver() {
        state = "dead"
        let dn = SKNode(); dn.zPosition = 50
        let t = SKLabelNode(text: "YOU DIED"); t.fontName = "Menlo-Bold"; t.fontSize = 48; t.fontColor = cRed
        t.position = CGPoint(x: WIN_W/2, y: WIN_H*0.6); dn.addChild(t)
        let sc = SKLabelNode(text: "Score: \(score)  |  Floor: \(floorNum)  |  Kills: \(killCount)")
        sc.fontName = "Menlo"; sc.fontSize = 16; sc.fontColor = NSColor(white: 0.6, alpha: 1)
        sc.position = CGPoint(x: WIN_W/2, y: WIN_H*0.48); dn.addChild(sc)
        let r = SKLabelNode(text: "[ PRESS SPACE ]"); r.fontName = "Menlo"; r.fontSize = 16
        r.fontColor = NSColor(white: 0.5, alpha: 1); r.position = CGPoint(x: WIN_W/2, y: WIN_H*0.35)
        r.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.7), SKAction.fadeAlpha(to: 0.9, duration: 0.7)])))
        dn.addChild(r)
        dn.alpha = 0; dn.run(SKAction.fadeIn(withDuration: 0.5))
        hudScene.addChild(dn); deathNode = dn
    }

    // MARK: - Items
    func checkItems() {
        let pp = playerNode.position
        for i in (0..<items.count).reversed() {
            let dist = (items[i].node.position - pp).flat
            if dist < 1.5 {
                switch items[i].type {
                case 0: // Potion
                    let heal = min(pMaxHP - pHP, 30 + floorNum * 5)
                    pHP += heal
                    spawnDmgNum(at: pp, amount: heal, color: cGreen)
                    showMessage("+\(heal) HP", duration: 1.0)
                case 1: // Key
                    hasKey = true; keyIcon.isHidden = false
                    showMessage("KEY ACQUIRED", duration: 1.5)
                default: break
                }
                items[i].node.removeFromParentNode(); items.remove(at: i)
            }
        }
    }

    func checkStairs(_ pressed: Set<UInt16>) {
        guard let sn = stairsNode else { return }
        let dist = (sn.position - playerNode.position).flat
        if dist < 2.5 {
            if !hasKey {
                if msgLabel.alpha < 0.1 { showMessage("FIND THE KEY", duration: 1.0) }
            } else if pressed.contains(14) { // E key
                showUpgrades()
            }
        }
    }

    // MARK: - Upgrades
    var upgradeOptions: [(String, String)] = []
    func showUpgrades() {
        state = "upgrading"
        let allUpgrades: [(String, String)] = [
            ("SHARP BLADE", "+20% Damage"),
            ("IRON SKIN", "+30 Max HP"),
            ("SWIFT FEET", "+15% Speed"),
            ("LONG REACH", "+25% Attack Speed"),
            ("VAMPIRIC", "+8% Lifesteal"),
            ("SECOND WIND", "Full Heal")
        ]
        let pool = allUpgrades.shuffled()
        upgradeOptions = Array(pool.prefix(3))

        let un = SKNode(); un.zPosition = 50
        let bg = SKShapeNode(rect: CGRect(x: 0, y: 0, width: WIN_W, height: WIN_H))
        bg.fillColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.7); bg.strokeColor = .clear
        un.addChild(bg)
        let title = SKLabelNode(text: "CHOOSE AN UPGRADE"); title.fontName = "Menlo-Bold"
        title.fontSize = 24; title.fontColor = cGold
        title.position = CGPoint(x: WIN_W/2, y: WIN_H * 0.75); un.addChild(title)

        for i in 0..<3 {
            let cx = WIN_W * CGFloat(i + 1) / 4
            let cardBG = SKShapeNode(rect: CGRect(x: cx - 100, y: WIN_H*0.35, width: 200, height: 180), cornerRadius: 8)
            cardBG.fillColor = NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.9)
            cardBG.strokeColor = cCyan; cardBG.lineWidth = 1; un.addChild(cardBG)
            let num = SKLabelNode(text: "[\(i+1)]"); num.fontName = "Menlo-Bold"; num.fontSize = 14
            num.fontColor = cCyan; num.position = CGPoint(x: cx, y: WIN_H*0.35 + 145); un.addChild(num)
            let name = SKLabelNode(text: upgradeOptions[i].0); name.fontName = "Menlo-Bold"
            name.fontSize = 15; name.fontColor = .white
            name.position = CGPoint(x: cx, y: WIN_H*0.35 + 110); un.addChild(name)
            let desc = SKLabelNode(text: upgradeOptions[i].1); desc.fontName = "Menlo"
            desc.fontSize = 12; desc.fontColor = NSColor(white: 0.6, alpha: 1)
            desc.position = CGPoint(x: cx, y: WIN_H*0.35 + 80); un.addChild(desc)
        }
        hudScene.addChild(un); upgradeNode = un
    }

    func applyUpgrade(_ index: Int) {
        guard index < upgradeOptions.count else { return }
        let name = upgradeOptions[index].0
        switch name {
        case "SHARP BLADE": pDmg = Int(CGFloat(pDmg) * 1.2)
        case "IRON SKIN": pMaxHP += 30; pHP = min(pMaxHP, pHP + 30)
        case "SWIFT FEET": pSpdMult *= 1.15
        case "LONG REACH": pAtkMult *= 1.25
        case "VAMPIRIC": pLifesteal += 0.08
        case "SECOND WIND": pHP = pMaxHP
        default: break
        }
        floorNum += 1; generateFloor()
    }

    // MARK: - HUD
    func updateHUD() {
        let pct = CGFloat(pHP) / CGFloat(pMaxHP)
        hpBar.path = CGPath(roundedRect: CGRect(x: 30, y: WIN_H-45, width: 220*pct, height: 16),
                            cornerWidth: 3, cornerHeight: 3, transform: nil)
        hpBar.fillColor = pct > 0.5 ? cGreen : (pct > 0.25 ? cGold : cRed)
        scoreLabel.text = "\(score)"
    }

    func updateMinimap() {
        let path = CGMutablePath()
        let s: CGFloat = 2.3
        for y in 0..<GRID_H {
            for x in 0..<GRID_W {
                if explored[y][x] && grid[y][x] == 1 {
                    path.addRect(CGRect(x: CGFloat(x)*s, y: CGFloat(GRID_H-1-y)*s, width: s-0.3, height: s-0.3))
                }
            }
        }
        mapFloor.path = path

        // Player dot
        let gx = Int(round(playerNode.position.x / TILE))
        let gy = Int(round(playerNode.position.z / TILE))
        mapPlayer.position = CGPoint(x: CGFloat(gx)*s + s/2, y: CGFloat(GRID_H-1-gy)*s + s/2)

        // Enemy dots
        for d in mapEnemyDots { d.removeFromParent() }
        mapEnemyDots.removeAll()
        for e in enemies {
            let ex = Int(round(e.node.position.x / TILE))
            let ey = Int(round(e.node.position.z / TILE))
            if ex >= 0 && ex < GRID_W && ey >= 0 && ey < GRID_H && explored[ey][ex] {
                let dot = SKShapeNode(circleOfRadius: 1.5)
                dot.fillColor = e.type == 0 ? cGreen : (e.type == 1 ? cOrange : cPurple)
                dot.strokeColor = .clear; dot.zPosition = 3
                dot.position = CGPoint(x: CGFloat(ex)*s + s/2, y: CGFloat(GRID_H-1-ey)*s + s/2)
                mapNode.addChild(dot); mapEnemyDots.append(dot)
            }
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let controller = GameController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let scr = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window = NSWindow(contentRect: NSRect(x: (scr.width-WIN_W)/2, y: (scr.height-WIN_H)/2,
                                              width: WIN_W, height: WIN_H),
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "SHADOW KEEP"
        window.backgroundColor = .black
        let gv = GameView(frame: NSRect(x: 0, y: 0, width: WIN_W, height: WIN_H))
        window.contentView = gv
        window.makeKeyAndOrderFront(nil); window.makeFirstResponder(gv)
        controller.setup(gv)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
