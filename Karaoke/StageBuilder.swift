//
//  StageBuilder.swift
//  Karaoke
//
//  Builds the immersive karaoke stage procedurally: a starry night dome,
//  a round stage with a neon rim, curtain, mic stand, speakers, a glowing
//  dance floor and swaying spotlight beams.
//

import RealityKit
import UIKit

/// Entities that the immersive view animates every frame.
struct StageRig {
    let root: Entity
    let starField: Entity
    let stars: [Entity]
    let beams: [Entity]
    let tiles: [ModelEntity]
    /// Where the lyric board should sit (above and behind the stage).
    let boardAnchor: Entity
}

enum StageBuilder {
    static let stageCenter = SIMD3<Float>(0, 0, -4.5)

    static func make() -> StageRig {
        let root = Entity()
        root.name = "KaraokeStage"

        let starField = makeSky(in: root)
        let stars = starField.children.map { $0 }
        makeFloor(in: root)
        let tiles = makeDanceFloor(in: root)
        makeStage(in: root)
        makeCurtain(in: root)
        makeMicStand(in: root)
        makeSpeakers(in: root)
        let beams = makeSpotlights(in: root)
        makeLights(in: root)

        let boardAnchor = Entity()
        boardAnchor.name = "LyricBoardAnchor"
        boardAnchor.position = [0, 2.7, -6.6]
        root.addChild(boardAnchor)

        return StageRig(root: root, starField: starField, stars: stars, beams: beams, tiles: tiles, boardAnchor: boardAnchor)
    }

    // MARK: - Sky

    private static func makeSky(in root: Entity) -> Entity {
        var skyMaterial = UnlitMaterial(color: UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1))
        skyMaterial.faceCulling = .front
        let sky = ModelEntity(mesh: .generateSphere(radius: 80), materials: [skyMaterial])
        sky.name = "Sky"
        root.addChild(sky)

        let starField = Entity()
        starField.name = "Stars"
        root.addChild(starField)

        let starMesh = MeshResource.generateSphere(radius: 0.12)
        let palette: [UIColor] = [
            .white,
            UIColor(red: 1.0, green: 0.95, blue: 0.75, alpha: 1),
            UIColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1),
        ]
        let materials = palette.map { UnlitMaterial(color: $0) }

        var generator = SystemRandomNumberGenerator()
        for index in 0..<420 {
            // Upper hemisphere only, so stars sit above the horizon.
            let azimuth = Float.random(in: 0..<(2 * .pi), using: &generator)
            let elevation = Float.random(in: 0.08...1.45, using: &generator)
            let radius: Float = Float.random(in: 50...70, using: &generator)
            let position = SIMD3<Float>(
                radius * cos(elevation) * sin(azimuth),
                radius * sin(elevation),
                radius * cos(elevation) * cos(azimuth)
            )
            let star = ModelEntity(mesh: starMesh, materials: [materials[index % materials.count]])
            star.position = position
            let size = Float.random(in: 0.4...1.6, using: &generator)
            star.scale = SIMD3(repeating: size)
            starField.addChild(star)
        }
        return starField
    }

    // MARK: - Floor

    private static func makeFloor(in root: Entity) {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.05, green: 0.04, blue: 0.08, alpha: 1))
        material.roughness = 0.35
        material.metallic = 0.4
        let floor = ModelEntity(mesh: .generatePlane(width: 60, depth: 60), materials: [material])
        floor.name = "Floor"
        root.addChild(floor)
    }

    private static func makeDanceFloor(in root: Entity) -> [ModelEntity] {
        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1),
            UIColor(red: 0.3, green: 0.4, blue: 1.0, alpha: 1),
            UIColor(red: 0.2, green: 0.9, blue: 0.9, alpha: 1),
            UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1),
        ]
        let size: Float = 0.58
        let gap: Float = 0.04
        let mesh = MeshResource.generateBox(width: size, height: 0.01, depth: size, cornerRadius: 0.02)
        var tiles: [ModelEntity] = []
        for row in 0..<4 {
            for column in -2...2 {
                var material = UnlitMaterial(color: colors[(row + column + 4) % colors.count])
                material.blending = .transparent(opacity: .init(floatLiteral: 0.35))
                let tile = ModelEntity(mesh: mesh, materials: [material])
                tile.position = [Float(column) * (size + gap), 0.006, -0.4 - Float(row) * (size + gap)]
                root.addChild(tile)
                tiles.append(tile)
            }
        }
        return tiles
    }

    // MARK: - Stage

    private static func makeStage(in root: Entity) {
        var deck = PhysicallyBasedMaterial()
        deck.baseColor = .init(tint: UIColor(red: 0.12, green: 0.08, blue: 0.1, alpha: 1))
        deck.roughness = 0.25
        deck.metallic = 0.6
        let platform = ModelEntity(mesh: .generateCylinder(height: 0.3, radius: 2.2), materials: [deck])
        platform.position = stageCenter + [0, 0.15, 0]
        platform.name = "Stage"
        root.addChild(platform)

        let neon = UnlitMaterial(color: UIColor(red: 1.0, green: 0.15, blue: 0.65, alpha: 1))
        let rim = ModelEntity(mesh: .generateCylinder(height: 0.04, radius: 2.24), materials: [neon])
        rim.position = stageCenter + [0, 0.25, 0]
        root.addChild(rim)

        let lowerRim = ModelEntity(
            mesh: .generateCylinder(height: 0.03, radius: 2.24),
            materials: [UnlitMaterial(color: UIColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1))]
        )
        lowerRim.position = stageCenter + [0, 0.03, 0]
        root.addChild(lowerRim)
    }

    private static func makeCurtain(in root: Entity) {
        var velvet = PhysicallyBasedMaterial()
        velvet.baseColor = .init(tint: UIColor(red: 0.35, green: 0.02, blue: 0.08, alpha: 1))
        velvet.roughness = 0.9
        velvet.sheen = .init(tint: UIColor(red: 1, green: 0.4, blue: 0.5, alpha: 1))

        // Pleated curtain: a row of slim boxes with alternating depth.
        let pleatWidth: Float = 0.45
        let count = 22
        for index in 0..<count {
            let x = (Float(index) - Float(count - 1) / 2) * pleatWidth
            let pleat = ModelEntity(
                mesh: .generateBox(width: pleatWidth * 1.05, height: 6, depth: 0.12, cornerRadius: 0.05),
                materials: [velvet]
            )
            pleat.position = [x, 3, -7.4 + (index.isMultiple(of: 2) ? 0 : 0.08)]
            root.addChild(pleat)
        }

        // Marquee bulbs across the top of the curtain.
        let bulb = MeshResource.generateSphere(radius: 0.05)
        let warm = UnlitMaterial(color: UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1))
        for index in 0..<30 {
            let x = (Float(index) - 14.5) * 0.32
            let light = ModelEntity(mesh: bulb, materials: [warm])
            light.position = [x, 5.6, -7.2]
            root.addChild(light)
        }
    }

    private static func makeMicStand(in root: Entity) {
        var chrome = PhysicallyBasedMaterial()
        chrome.baseColor = .init(tint: UIColor(white: 0.85, alpha: 1))
        chrome.metallic = 1.0
        chrome.roughness = 0.15

        let base = stageCenter + [0, 0.3, 1.2]
        let foot = ModelEntity(mesh: .generateCylinder(height: 0.03, radius: 0.18), materials: [chrome])
        foot.position = base + [0, 0.015, 0]
        let pole = ModelEntity(mesh: .generateCylinder(height: 1.45, radius: 0.012), materials: [chrome])
        pole.position = base + [0, 0.725, 0]

        var grille = PhysicallyBasedMaterial()
        grille.baseColor = .init(tint: UIColor(white: 0.25, alpha: 1))
        grille.metallic = 0.9
        grille.roughness = 0.4
        let head = ModelEntity(mesh: .generateSphere(radius: 0.045), materials: [grille])
        head.position = base + [0, 1.5, 0.02]

        for part in [foot, pole, head] {
            root.addChild(part)
        }
    }

    private static func makeSpeakers(in root: Entity) {
        var cabinet = PhysicallyBasedMaterial()
        cabinet.baseColor = .init(tint: UIColor(white: 0.06, alpha: 1))
        cabinet.roughness = 0.7

        var cone = PhysicallyBasedMaterial()
        cone.baseColor = .init(tint: UIColor(white: 0.15, alpha: 1))
        cone.roughness = 0.5
        let glow = UnlitMaterial(color: UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1))

        for side: Float in [-1, 1] {
            let speaker = Entity()
            speaker.position = [side * 3.4, 0, -4.2]
            speaker.orientation = simd_quatf(angle: -side * 0.35, axis: [0, 1, 0])
            root.addChild(speaker)

            let box = ModelEntity(mesh: .generateBox(width: 0.8, height: 1.6, depth: 0.6, cornerRadius: 0.04), materials: [cabinet])
            box.position = [0, 0.8, 0]
            speaker.addChild(box)

            for (height, radius) in [(Float(1.25), Float(0.16)), (0.6, 0.28)] {
                let ring = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: radius + 0.02), materials: [glow])
                ring.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                ring.position = [0, height, 0.3]
                speaker.addChild(ring)

                let driver = ModelEntity(mesh: .generateCylinder(height: 0.03, radius: radius), materials: [cone])
                driver.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                driver.position = [0, height, 0.31]
                speaker.addChild(driver)
            }
        }
    }

    // MARK: - Lighting

    private static func makeSpotlights(in root: Entity) -> [Entity] {
        let colors: [UIColor] = [
            UIColor(red: 1.0, green: 0.3, blue: 0.7, alpha: 1),
            UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1),
            UIColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1),
            UIColor(red: 0.4, green: 1.0, blue: 0.9, alpha: 1),
            UIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1),
        ]
        let beamLength: Float = 5.5
        var housing = PhysicallyBasedMaterial()
        housing.baseColor = .init(tint: UIColor(white: 0.1, alpha: 1))
        housing.metallic = 0.8

        var pivots: [Entity] = []
        for (index, color) in colors.enumerated() {
            let x = (Float(index) - 2) * 1.5
            let pivot = Entity()
            pivot.position = [x, 6.0, -5.2]
            root.addChild(pivot)

            let can = ModelEntity(mesh: .generateCylinder(height: 0.3, radius: 0.12), materials: [housing])
            pivot.addChild(can)

            var beamMaterial = UnlitMaterial(color: color)
            beamMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.05))
            beamMaterial.faceCulling = .none
            // generateCone puts the apex at +y; hang it so the apex sits at the fixture.
            let beam = ModelEntity(mesh: .generateCone(height: beamLength, radius: 0.7), materials: [beamMaterial])
            beam.position = [0, -beamLength / 2, 0]
            pivot.addChild(beam)

            var spot = SpotLightComponent(color: color, intensity: 6000, innerAngleInDegrees: 12, outerAngleInDegrees: 22, attenuationRadius: 12)
            spot.attenuationFalloffExponent = 1.5
            let light = Entity()
            light.components.set(spot)
            // Spot lights shine down -z; tip it to point down the beam.
            light.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            pivot.addChild(light)

            pivots.append(pivot)
        }
        return pivots
    }

    private static func makeLights(in root: Entity) {
        let fill = Entity()
        fill.components.set(PointLightComponent(color: UIColor(red: 0.6, green: 0.5, blue: 1.0, alpha: 1), intensity: 30000, attenuationRadius: 14))
        fill.position = [0, 4, -1]
        root.addChild(fill)

        let key = Entity()
        key.components.set(DirectionalLightComponent(color: UIColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 1), intensity: 600))
        key.look(at: [0, 0, -4], from: [2, 6, 2], relativeTo: nil)
        root.addChild(key)
    }
}
