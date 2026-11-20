// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ItamarOSiPhoneStudio",
    platforms: [.iOS(.v16)],
    products: [.library(name: "StudioCore", targets: ["StudioCore"])],
    targets: [
        .target(name: "StudioCore", path: "Sources/StudioCore")
    ]
)
