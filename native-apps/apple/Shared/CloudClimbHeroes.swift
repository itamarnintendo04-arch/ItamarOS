import SwiftUI

/// Original Cloud Climb cosmetic characters. IDs match existing server rewards.
struct CloudClimbHero: Identifiable {
    let id:String
    let name:String
    let emoji:String
    let tint:Color
    let scarf:Color
}

enum CloudClimbHeroes {
    static let regular:[CloudClimbHero] = [
        .init(id:"starter",name:"Cloud Scout",emoji:"☁️",tint:.white,scarf:.blue),
        .init(id:"sky_01",name:"Sky Fox",emoji:"🦊",tint:.orange,scarf:.blue),
        .init(id:"sky_02",name:"Nimbus Cat",emoji:"🐱",tint:.yellow,scarf:.purple),
        .init(id:"sky_03",name:"Breeze Bunny",emoji:"🐰",tint:.pink,scarf:.cyan),
        .init(id:"sky_04",name:"Rain Penguin",emoji:"🐧",tint:.cyan,scarf:.orange),
        .init(id:"sky_05",name:"Star Pup",emoji:"🐶",tint:.brown,scarf:.mint),
        .init(id:"sky_06",name:"Cloud Bear",emoji:"🐻",tint:.brown,scarf:.pink),
        .init(id:"sky_07",name:"Comet Owl",emoji:"🦉",tint:.purple,scarf:.yellow),
        .init(id:"sky_08",name:"Mist Koala",emoji:"🐨",tint:.gray,scarf:.cyan),
        .init(id:"sky_09",name:"Aurora Dragon",emoji:"🐉",tint:.mint,scarf:.pink),
        .init(id:"sky_10",name:"Kite Frog",emoji:"🐸",tint:.green,scarf:.blue),
        .init(id:"sky_11",name:"Moon Bat",emoji:"🦇",tint:.indigo,scarf:.yellow),
        .init(id:"sky_12",name:"Sun Lion",emoji:"🦁",tint:.yellow,scarf:.orange)
    ]
    static let mystery:[CloudClimbHero] = [
        ("💎",Color.cyan),("🪄",Color.purple),("🌸",Color.pink),
        ("🪸",Color.orange),("🧊",Color.blue),("🌿",Color.green),
        ("🌋",Color.red),("🌙",Color.indigo),("⚡",Color.yellow),
        ("🌈",Color.mint)
    ].enumerated().map { index,entry in
        CloudClimbHero(id:"mystery_world_\(index+1)",name:"World \(index+1) Mystery",
            emoji:entry.0,tint:entry.1,scarf:.blue)
    }
    static let all=regular+mystery
    static func unlocked(_ id:String,owned:Set<String>)->Bool {
        id=="starter" || owned.contains(id)
    }
    static func get(_ id:String)->CloudClimbHero {
        all.first(where:{$0.id==id}) ?? regular[0]
    }

    /// Draw a real, recognizable mascot on the stage instead of a rectangle.
    static func draw(_ ctx:GraphicsContext,hero id:String,x:CGFloat,y:CGFloat,
                     sx:CGFloat,sy:CGFloat) {
        let hero=get(id)
        let cx=x*sx,cy=y*sy
        ctx.fill(Path(ellipseIn:CGRect(x:cx-15*sx,y:cy+2*sy,
            width:30*sx,height:12*sy)),with:.color(.indigo.opacity(0.4)))
        if id != "starter" {
            for direction in [-1.0,1.0] {
                ctx.fill(Path(ellipseIn:CGRect(x:cx+CGFloat(direction)*9*sx-5*sx,
                    y:cy-25*sy,width:10*sx,height:12*sy)),with:.color(hero.tint))
            }
        }
        ctx.fill(Path(roundedRect:CGRect(x:cx-13*sx,y:cy-20*sy,
                width:26*sx,height:29*sy),cornerRadius:11),
                 with:.color(hero.tint))
        ctx.fill(Path(roundedRect:CGRect(x:cx-13*sx,y:cy-5*sy,
                width:27*sx,height:6*sy),cornerRadius:3),
                 with:.color(hero.scarf))
        for shift in [-5.0,5.0] {
            ctx.fill(Path(ellipseIn:CGRect(x:cx+CGFloat(shift)*sx-2*sx,
                y:cy-14*sy,width:4*sx,height:6*sy)),with:.color(.black))
        }
        ctx.fill(Path(ellipseIn:CGRect(x:cx-2*sx,y:cy-6*sy,
            width:4*sx,height:3*sy)),with:.color(.pink))
        if id != "starter" {
            ctx.draw(Text(hero.emoji).font(.system(size:10)),
                     at:CGPoint(x:cx,y:cy-27*sy))
        }
    }
}

struct CloudClimbHeroPicker:View {
    let owned:Set<String>
    @Binding var selected:String

    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            Text("CHARACTERS · \(owned.count+1)/23 unlocked")
                .font(.headline).foregroundStyle(.white)
            Text("Select an unlocked hero. Characters are cosmetic.")
                .font(.caption).foregroundStyle(.white.opacity(0.8))
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:9) {
                    ForEach(CloudClimbHeroes.all) { hero in
                        let available=CloudClimbHeroes.unlocked(hero.id,owned:owned)
                        Button {
                            if available {selected=hero.id}
                        } label: {
                            VStack(spacing:4) {
                                Text(hero.emoji).font(.system(size:33))
                                Text(hero.name).font(.caption2.bold())
                                    .lineLimit(2).multilineTextAlignment(.center)
                                Text(!available ? "LOCKED" :
                                    selected==hero.id ? "EQUIPPED" : "SELECT")
                                    .font(.system(size:9,weight:.heavy))
                            }
                            .foregroundStyle(.white)
                            .frame(width:99,height:93)
                            .background(selected==hero.id ? Color.blue.opacity(0.75) :
                                Color.indigo.opacity(0.36),in:RoundedRectangle(cornerRadius:14))
                            .overlay(RoundedRectangle(cornerRadius:14)
                                .stroke(selected==hero.id ? Color.yellow :
                                    Color.white.opacity(0.25),lineWidth:2))
                        }
                        .disabled(!available)
                        .opacity(available ? 1 : 0.5)
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
