//
//  ARView.swift
//  MaterialsDemo
//
//  Created by Nien Lam on 11/1/23.
//  Copyright © 2023 Line Break, LLC. All rights reserved.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

// FILTER:
import CoreImage.CIFilterBuiltins


// MARK: - AR View.
struct ARViewContainer: UIViewRepresentable {
    let viewModel: ViewModel
    
    func makeUIView(context: Context) -> ARView {
        SimpleARView(frame: .zero, viewModel: viewModel)
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class SimpleARView: ARView {
    var viewModel: ViewModel
    var arView: ARView { return self }
    var originAnchor: AnchorEntity!
    var subscriptions = Set<AnyCancellable>()
    
    // Empty entity for cursor.
    var cursor: Entity!
    
    // Custom entities.
    var chair: ModelEntity!
    
    // Scene lights.
    var directionalLight: DirectionalLight!
    
    // Parent entity for spheres.
    var spheres: Entity!
    
    // Entity for checkerboard.
    var checkerBoardPlane: Entity!
    
    // FILTER:
    var context: CIContext?
    var device: MTLDevice!
    
    init(frame: CGRect, viewModel: ViewModel) {
        self.viewModel = viewModel
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        setupScene()
        
        setupEntities()
        
        setupSubscriptions()
    }
    
    func setupScene() {
        // Setup world tracking and plane detection.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.run(configuration)
        
        // FILTER:
        arView.renderCallbacks.prepareWithDevice = { [weak self] device in
            self?.context = CIContext(mtlDevice: device)
            self?.device = device
        }
        
        // Add a gesture recognizer to detect taps.
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let tapLocation = sender.location(in: arView)
            
            guard let hitEntity = self.entity(at: tapLocation) else { return }
            
            if hitEntity.name == "chair" {
                playAudioFileFor(entity: chair)
            }
        }
    }
    
    func setupSubscriptions() {
        // Called every frame.
        scene.subscribe(to: SceneEvents.Update.self) { event in
            if !self.viewModel.positionIsLocked {
                self.updateCursor()
            }
        }
        .store(in: &subscriptions)
        
        
        // Reset chair transform if positionIsLocked is toggled.
        viewModel.$positionIsLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                
                // If enabled, create plane anchor and move cursor to plane anchor.
                if enabled {
                    let anchorEntity = AnchorEntity(plane: [.horizontal, .vertical],
                                                    minimumBounds: [0.25, 0.25])
                    arView.scene.anchors.append(anchorEntity)
                    anchorEntity.addChild(cursor, preservingWorldTransform: true)
                } else {
                    // Reset chair transform.
                    chair.transform = Transform(scale: [0.01, 0.01, 0.01])
                    
                    // Disable filters.
                    viewModel.filtersIdx = 0
                }
            }
            .store(in: &subscriptions)
        
        
        // Enable / disable entities.
        
        viewModel.$chairEnabled
            .sink { [weak self] enabled in
                self?.chair.isEnabled = enabled
            }
            .store(in: &subscriptions)
        
        viewModel.$directionalLightEnabled
            .sink { [weak self] enabled in
                self?.directionalLight.isEnabled = enabled
            }
            .store(in: &subscriptions)
        
        viewModel.$sphereEnabled
            .sink { [weak self] enabled in
                self?.spheres.isEnabled = enabled
            }
            .store(in: &subscriptions)
        
        viewModel.$boardEnabled
            .sink { [weak self] enabled in
                self?.checkerBoardPlane.isEnabled = enabled
            }
            .store(in: &subscriptions)
        
        
        // Filters.
        
        viewModel.$filtersIdx
            .sink { [weak self] idx in
                guard let self else { return }
                
                // Idx of 0 turns filters off.
                if idx > 0 {
                    arView.renderCallbacks.postProcess = { [weak self] context in
                        self?.filter(context)
                    }
                } else {
                    arView.renderCallbacks.postProcess = nil
                }
            }
            .store(in: &subscriptions)
    }
    
    // Move cursor to plane detected.
    func updateCursor() {
        // Raycast to get cursor position.
        let results = raycast(from: center,
                              allowing: .existingPlaneGeometry,
                              alignment: .any)
        
        // Move cursor to position if hitting plane.
        if let result = results.first {
            cursor.isEnabled = true
            cursor.move(to: result.worldTransform, relativeTo: originAnchor)
        } else {
            cursor.isEnabled = false
        }
    }
    
    func setupEntities() {
        // Create an anchor at scene origin.
        originAnchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(originAnchor)
        
        // Create and add empty cursor entity to origin anchor.
        cursor = Entity()
        originAnchor.addChild(cursor)
        
        // Create parent entity for spheres
        spheres = Entity()
        cursor.addChild(spheres)
        
        // Add directional light.
        directionalLight = DirectionalLight()
        directionalLight.light.intensity = 1000
        directionalLight.look(at: [0,0,0], from: [1, 1.1, 1.3], relativeTo: originAnchor)
        directionalLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 0.5, depthBias: 2)
        originAnchor.addChild(directionalLight)
        
        // create chair entity and add gestures.
        chair = makeModelEntity(name: "chair", usdzModelName: "chair")
        chair.generateCollisionShapes(recursive: false)
        self.installGestures(.all, for: chair)
        cursor.addChild(chair)
        
        
        // Add checkerboard plane.
        var checkerBoardMaterial = PhysicallyBasedMaterial()
        checkerBoardMaterial.baseColor.texture = .init(try! .load(named: "checker.png"))
        checkerBoardPlane = ModelEntity(mesh: .generatePlane(width: 0.5, depth: 0.5), materials: [checkerBoardMaterial])
        checkerBoardPlane.position.y = 0.001
        cursor.addChild(checkerBoardPlane)
        
        
        // Array or spheres with different material properties.
        
        let sphereSize: Float = 0.03
        
        for roughnessStep in 0...2 {
            // Increment roughness.
            let roughness = Float(roughnessStep) * 0.5
            
            for metallicStep in 0...2 {
                // Increment metallic.
                let metallic = Float(metallicStep) * 0.5
                
                // Vary roughness and metallic.
                var material = PhysicallyBasedMaterial()
                material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: .purple)
                material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: roughness)
                material.metallic  = PhysicallyBasedMaterial.Metallic(floatLiteral: metallic)
                
                // Position sphere in a grid.
                let sphereEntity = ModelEntity(mesh: .generateSphere(radius: sphereSize), materials: [material])
                sphereEntity.position.y = sphereSize
                sphereEntity.position.x = Float(roughnessStep) * sphereSize * 2
                sphereEntity.position.z = Float(metallicStep) * sphereSize * 2
                
                spheres.addChild(sphereEntity)
            }
        }
    }
    
    // FILTER:
    func filter(_ context: ARView.PostProcessContext) {
        let inputImage = CIImage(mtlTexture: context.sourceColorTexture)!
        
        // Change filter here.
        // Reference: https://developer.apple.com/documentation/coreimage/processing_an_image_using_built-in_filters
        
        // Reference to filter selected.
        var selectedFilter: CIFilter!
        
        switch viewModel.filtersIdx {
        case 1:
            // Crystallize filter.
            let filter = CIFilter.crystallize()
            filter.setValue(40, forKey: kCIInputRadiusKey)
            filter.inputImage = inputImage
            selectedFilter = filter
        case 2:
            // Pixellate filter
            let filter = CIFilter.pixellate()
            filter.setValue(20, forKey: kCIInputScaleKey)
            filter.inputImage = inputImage
            selectedFilter = filter
        case 3:
            // Sepia filter
            let filter = CIFilter.sepiaTone()
            filter.setValue(0.9, forKey: kCIInputIntensityKey)
            filter.inputImage = inputImage
            selectedFilter = filter
        case 4:
            // B&W filter
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = inputImage
            selectedFilter = filter
        case 5:
            // Bloom filter
            let filter = CIFilter.bloom()
            filter.setValue(1.0, forKey: kCIInputIntensityKey)
            filter.setValue(100, forKey: kCIInputRadiusKey)
            filter.inputImage = inputImage
            selectedFilter = filter
        default:
            fatalError()
        }
        
        let destination = CIRenderDestination(mtlTexture: context.targetColorTexture,
                                              commandBuffer: context.commandBuffer)
        
        destination.isFlipped = false
        
        _ = try? self.context?.startTask(toRender: selectedFilter.outputImage!, to: destination)
    }

    
    // Add audio file to entity.
    func playAudioFileFor(entity: Entity) {
        do {
          let resource = try AudioFileResource.load(named: "piano-scale.m4a",
                                                    in: nil,
                                                    inputMode: .spatial,
                                                    loadingStrategy: .preload,
                                                    shouldLoop: false)
          
          let audioController = entity.prepareAudio(resource)
          audioController.play()
        } catch {
          print("Error loading audio file")
        }
    }
}
