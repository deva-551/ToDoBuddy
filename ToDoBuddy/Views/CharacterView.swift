import SwiftUI
import SceneKit

// MARK: - Character View (3D character with floating sign above head)

struct CharacterView: View {
    let currentTaskTitle: String?
    var modelName: String = "character"

    var body: some View {
        CharacterSceneView(taskTitle: currentTaskTitle ?? "All done!", modelName: modelName)
            .frame(width: 420, height: 280)
            .id(modelName) // Force full recreation when character changes
    }
}

// MARK: - SceneKit 3D Character View

struct CharacterSceneView: NSViewRepresentable {

    let taskTitle: String
    let modelName: String

    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = .clear
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.preferredFramesPerSecond = 30
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true

        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        loadCharacter(into: scene)
        setupCamera(in: scene)
        setupLighting(in: scene)

        scnView.scene = scene
        return scnView
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // Update sign text when task changes
        guard let scene = nsView.scene,
              let signNode = scene.rootNode.childNode(withName: "signBoard", recursively: true),
              let bgNode = signNode.childNodes.first,
              let plane = bgNode.geometry as? SCNPlane else { return }
        let (newImage, newSize) = renderSignImage(text: taskTitle)
        plane.materials.first?.diffuse.contents = newImage
        let scaleToScene: CGFloat = 0.05
        plane.width = newSize.width * scaleToScene
        plane.height = newSize.height * scaleToScene
        plane.cornerRadius = plane.height * 0.12
    }

    // MARK: - Create 3D Sign Board

    private func createSignNode(text: String) -> SCNNode {
        let signNode = SCNNode()
        signNode.name = "signBoard"

        // Measure text and render image sized to fit
        let (signImage, imageSize) = renderSignImage(text: text)

        // Convert pixel size to 3D scene units (in head's local unscaled space)
        // ~0.097 wrapper scale, so multiply by ~10 to get scene-visible size
        let scaleToScene: CGFloat = 0.05
        let planeWidth = imageSize.width * scaleToScene
        let planeHeight = imageSize.height * scaleToScene

        let bgPlane = SCNPlane(width: planeWidth, height: planeHeight)
        let bgMaterial = SCNMaterial()
        bgMaterial.diffuse.contents = signImage
        bgMaterial.lightingModel = .constant
        bgMaterial.isDoubleSided = true
        bgMaterial.transparencyMode = .aOne
        bgPlane.materials = [bgMaterial]
        bgPlane.cornerRadius = planeHeight * 0.12

        let bgNode = SCNNode(geometry: bgPlane)
        signNode.addChildNode(bgNode)

        // Always face the camera
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        signNode.constraints = [billboard]

        return signNode
    }

    /// Measures the text, sizes the card to fit, and renders it as an image
    private func renderSignImage(text: String) -> (NSImage, NSSize) {
        let font = NSFont.systemFont(ofSize: 28, weight: .bold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(red: 0.32, green: 0.20, blue: 0.08, alpha: 1),
            .paragraphStyle: paragraphStyle,
        ]

        // Measure text size (max width 400, allow wrapping)
        let maxTextWidth: CGFloat = 400
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let textBounds = attrString.boundingRect(
            with: NSSize(width: maxTextWidth, height: 200),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        // Add padding around text
        let padX: CGFloat = 36
        let padY: CGFloat = 24
        let minWidth: CGFloat = 160
        let imgWidth = max(ceil(textBounds.width) + padX * 2, minWidth)
        let imgHeight = ceil(textBounds.height) + padY * 2

        let imageSize = NSSize(width: imgWidth, height: imgHeight)
        let image = NSImage(size: imageSize)
        image.lockFocus()

        let rect = NSRect(origin: .zero, size: imageSize)
        let cardRect = rect.insetBy(dx: 3, dy: 3)
        let path = NSBezierPath(roundedRect: cardRect, xRadius: 12, yRadius: 12)

        // Shadow
        let shadowRect = cardRect.offsetBy(dx: 0, dy: -3)
        let shadowPath = NSBezierPath(roundedRect: shadowRect, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.15).setFill()
        shadowPath.fill()

        // Background
        NSColor(red: 0.98, green: 0.92, blue: 0.78, alpha: 1).setFill()
        path.fill()

        // Border
        NSColor(red: 0.68, green: 0.52, blue: 0.30, alpha: 1).setStroke()
        path.lineWidth = 3.5
        path.stroke()

        // Draw text centered
        let textRect = NSRect(
            x: padX,
            y: (imgHeight - textBounds.height) / 2,
            width: imgWidth - padX * 2,
            height: textBounds.height
        )
        attrString.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

        image.unlockFocus()
        return (image, imageSize)
    }

    // MARK: - Load Character

    private func loadCharacter(into scene: SCNScene) {
        let extensions = ["dae", "scn", "usdz"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: modelName, withExtension: ext),
               let modelScene = try? SCNScene(url: url) {
                setupAnimatedModel(modelScene, into: scene)
                return
            }
        }

        if let objURL = Bundle.main.url(forResource: "paimon", withExtension: "obj"),
           let modelScene = try? SCNScene(url: objURL) {
            setupStaticModel(modelScene, into: scene)
            return
        }

        let placeholder = createPlaceholder()
        scene.rootNode.addChildNode(placeholder)
        startFallbackWalkCycle(on: placeholder)
    }

    // MARK: - Animated Model (DAE from Mixamo)

    private func setupAnimatedModel(_ modelScene: SCNScene, into scene: SCNScene) {
        let wrapper = SCNNode()
        wrapper.name = "walkWrapper"

        let children = modelScene.rootNode.childNodes
        for child in children {
            child.removeFromParentNode()
            wrapper.addChildNode(child)
        }

        // Scale to fit
        let (minBound, maxBound) = wrapper.boundingBox
        let modelHeight = maxBound.y - minBound.y
        if modelHeight > 0 {
            let targetHeight: CGFloat = 1.6
            let s = Float(targetHeight / modelHeight)
            wrapper.scale = SCNVector3(s, s, s)
        }

        // Center
        let (sMin, sMax) = wrapper.boundingBox
        let centerX = (sMin.x + sMax.x) / 2 * CGFloat(wrapper.scale.x)
        let bottomY = sMin.y * CGFloat(wrapper.scale.y)
        wrapper.position = SCNVector3(-Float(centerX), -Float(bottomY), 0)

        scene.rootNode.addChildNode(wrapper)

        // Attach sign above the character — always on wrapper for reliability
        let signNode = createSignNode(text: taskTitle)
        signNode.name = "signBoard"
        let billboard = SCNBillboardConstraint()
        billboard.freeAxes = [.X, .Y]
        signNode.constraints = [billboard]

        // Position above model top in wrapper's local (unscaled) space
        let signY = Float(sMax.y) + Float(modelHeight) * 0.2
        signNode.position = SCNVector3(0, signY, 0)

        // Compensate for wrapper's scale so sign always appears the same visual size
        // The sign plane uses scaleToScene=0.05 internally. We want:
        //   visual_size = plane_local_size * signScale * wrapperScale = constant
        // So signScale = constant / (0.05 * wrapperScale) = 0.1 / wrapperScale
        let signCompensation = Float(0.1) / Float(wrapper.scale.x)
        signNode.scale = SCNVector3(signCompensation, signCompensation, signCompensation)

        wrapper.addChildNode(signNode)

        ensureAnimationsLoop(on: wrapper)
    }

    // MARK: - Ensure Animations Loop

    private func ensureAnimationsLoop(on node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            for key in child.animationKeys {
                if let player = child.animationPlayer(forKey: key) {
                    player.animation.isRemovedOnCompletion = false
                    player.animation.repeatCount = .infinity
                    player.play()
                }
            }
        }
        for key in node.animationKeys {
            if let player = node.animationPlayer(forKey: key) {
                player.animation.isRemovedOnCompletion = false
                player.animation.repeatCount = .infinity
                player.play()
            }
        }
    }

    // MARK: - Static Model (OBJ fallback)

    private func setupStaticModel(_ modelScene: SCNScene, into scene: SCNScene) {
        let characterNode = SCNNode()
        characterNode.name = "character"
        for child in modelScene.rootNode.childNodes {
            characterNode.addChildNode(child.clone())
        }

        applyBundledTexture(to: characterNode)

        let (minBound, maxBound) = characterNode.boundingBox
        let modelHeight = maxBound.y - minBound.y
        if modelHeight > 0 {
            let s = Float(1.6 / modelHeight)
            characterNode.scale = SCNVector3(s, s, s)
        }

        let (sMin, sMax) = characterNode.boundingBox
        let centerX = (sMin.x + sMax.x) / 2 * CGFloat(characterNode.scale.x)
        let centerY = (sMin.y + sMax.y) / 2 * CGFloat(characterNode.scale.y)
        characterNode.position = SCNVector3(-Float(centerX), -Float(centerY), 0)

        let wrapper = SCNNode()
        wrapper.name = "walkWrapper"
        wrapper.addChildNode(characterNode)
        scene.rootNode.addChildNode(wrapper)

        // Add sign above static model too
        let signNode = createSignNode(text: taskTitle)
        signNode.position = SCNVector3(0, 1.8, 0)
        wrapper.addChildNode(signNode)

        startFallbackWalkCycle(on: wrapper)
    }

    private func applyBundledTexture(to node: SCNNode) {
        guard let texURL = Bundle.main.url(forResource: "paimon_tex_1", withExtension: "png"),
              let texImage = NSImage(contentsOf: texURL) else {
            if let texURL = Bundle.main.url(forResource: "paimon_tex_0", withExtension: "jpg"),
               let texImage = NSImage(contentsOf: texURL) {
                applyImage(texImage, to: node)
            }
            return
        }
        applyImage(texImage, to: node)
    }

    private func applyImage(_ image: NSImage, to node: SCNNode) {
        node.enumerateChildNodes { child, _ in
            if let geometry = child.geometry {
                let material = SCNMaterial()
                material.diffuse.contents = image
                material.diffuse.wrapS = .repeat
                material.diffuse.wrapT = .repeat
                material.isDoubleSided = true
                material.lightingModel = .physicallyBased
                material.roughness.contents = NSNumber(value: 0.6)
                material.metalness.contents = NSNumber(value: 0.1)
                geometry.materials = [material]
            }
        }
    }

    // MARK: - Fallback Walk Cycle

    private func startFallbackWalkCycle(on node: SCNNode) {
        let stepDist: CGFloat = 0.3
        let stepTime: TimeInterval = 0.35
        let turnTime: TimeInterval = 0.25

        let bounceUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: stepTime * 0.35)
        bounceUp.timingMode = .easeOut
        let bounceDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: stepTime * 0.65)
        bounceDown.timingMode = .easeIn
        let bounce = SCNAction.sequence([bounceUp, bounceDown])

        let leanRight = SCNAction.rotateTo(x: 0, y: 0, z: -0.06, duration: stepTime * 0.4)
        let leanLeft = SCNAction.rotateTo(x: 0, y: 0, z: 0.06, duration: stepTime * 0.4)
        let leanBack = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: stepTime * 0.3)

        let moveRight = SCNAction.moveBy(x: stepDist, y: 0, z: 0, duration: stepTime)
        moveRight.timingMode = .easeInEaseOut
        let stepRight = SCNAction.group([moveRight, bounce, SCNAction.sequence([leanRight, leanBack])])

        let moveLeft = SCNAction.moveBy(x: -stepDist, y: 0, z: 0, duration: stepTime)
        moveLeft.timingMode = .easeInEaseOut
        let stepLeft = SCNAction.group([moveLeft, bounce, SCNAction.sequence([leanLeft, leanBack])])

        let faceRight = SCNAction.rotateTo(x: 0, y: -.pi / 2, z: 0, duration: turnTime)
        faceRight.timingMode = .easeInEaseOut
        let faceLeft = SCNAction.rotateTo(x: 0, y: .pi / 2, z: 0, duration: turnTime)
        faceLeft.timingMode = .easeInEaseOut
        let faceCamera = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: turnTime)
        faceCamera.timingMode = .easeInEaseOut

        let idleUp = SCNAction.moveBy(x: 0, y: 0.04, z: 0, duration: 0.7)
        idleUp.timingMode = .easeInEaseOut
        let idleDown = SCNAction.moveBy(x: 0, y: -0.04, z: 0, duration: 0.7)
        idleDown.timingMode = .easeInEaseOut
        let idleBob = SCNAction.sequence([idleUp, idleDown])

        let lookLeft = SCNAction.rotateTo(x: 0, y: CGFloat.pi * 0.08, z: 0, duration: 1.0)
        lookLeft.timingMode = .easeInEaseOut
        let lookRight = SCNAction.rotateTo(x: 0, y: -CGFloat.pi * 0.08, z: 0, duration: 1.0)
        lookRight.timingMode = .easeInEaseOut
        let lookCenter = SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.5)
        lookCenter.timingMode = .easeInEaseOut

        let idlePhase = SCNAction.group([
            SCNAction.repeat(idleBob, count: 2),
            SCNAction.sequence([lookLeft, lookRight, lookCenter])
        ])

        let cycle = SCNAction.sequence([
            faceCamera, idlePhase,
            faceRight, stepRight, stepRight,
            faceCamera, idlePhase,
            faceLeft, stepLeft, stepLeft,
        ])

        node.runAction(SCNAction.repeatForever(cycle))
    }

    // MARK: - Placeholder

    private func createPlaceholder() -> SCNNode {
        let box = SCNBox(width: 0.5, height: 0.8, length: 0.5, chamferRadius: 0.05)
        let material = SCNMaterial()
        material.diffuse.contents = NSColor.systemTeal
        material.lightingModel = .physicallyBased
        box.materials = [material]
        let node = SCNNode(geometry: box)
        node.name = "walkWrapper"
        return node
    }

    // MARK: - Camera

    private func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        // Offset camera left so character appears on the right side of the wider view
        cameraNode.position = SCNVector3(-2.0, 1.5, 4.2)
        cameraNode.look(at: SCNVector3(-0.8, 1.2, 0))
        scene.rootNode.addChildNode(cameraNode)
    }

    // MARK: - Lighting

    private func setupLighting(in scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 600
        ambient.light?.color = NSColor(white: 0.95, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1000
        key.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 400
        fill.light?.color = NSColor(red: 0.9, green: 0.92, blue: 1.0, alpha: 1)
        fill.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fill)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 300
        rim.light?.color = NSColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1)
        rim.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi, 0)
        scene.rootNode.addChildNode(rim)
    }
}
