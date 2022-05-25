//
//  ViewController.swift
//  Visual Signal
//
//  Created by Vergil Choi on 2018/12/29.
//  Copyright © 2018 Vergil Choi. All rights reserved.
//

import UIKit
import SceneKit
import ARKit


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var strengthLabel: UILabel!
    
    var cameraTransform = simd_float4x4()
    var timer: Timer!
    var currentNode: SCNNode?
    var currentLabelNode: SCNNode?
    var link: CADisplayLink?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/main.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) else {
            print("meshWithClassification isn't supported here.")
            return
        }
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
            self.strengthLabel.text = String(format: "  WiFi Strength: %.02f%%  ", self.wifiStrength() * 100)
        })
        timer.fire()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        timer.invalidate()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let strength = wifiStrength()
        let sphere = SCNSphere(radius: 0.01)
        sphere.firstMaterial?.diffuse.contents = UIColor(
            hue: CGFloat((2 * strength - strength * strength) / 2),
            saturation: 1, brightness: 1, alpha: 1
        )
        currentLabelNode = TextNode(text: String(format: "%.02f%%", strength * 100), font: "AvenirNext-Regular", colour: UIColor(
            hue: CGFloat((2 * strength - strength * strength) / 2),
            saturation: 1, brightness: 1, alpha: 1
        ))
        
        currentNode = SCNNode(geometry: sphere)
        updatePositionAndOrientationOf(currentNode!, withPosition: SCNVector3(0, 0, -0.15), relativeTo: sceneView.pointOfView!)
        updatePositionAndOrientationOf(currentLabelNode!, withPosition: SCNVector3(0, 0.02, -0.15), relativeTo: sceneView.pointOfView!)
        sceneView.scene.rootNode.addChildNode(currentNode!)
        sceneView.scene.rootNode.addChildNode(currentLabelNode!)
        
        link = CADisplayLink(target: self, selector: #selector(scalingNode))
        link?.add(to: RunLoop.main, forMode: .common)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        link?.invalidate()
    }
    
    @objc func scalingNode() {
        if let node = currentNode {
            node.scale = SCNVector3(node.scale.x + 0.02, node.scale.y + 0.02, node.scale.z + 0.02)
        }
        if let node = currentLabelNode {
            node.scale = SCNVector3(node.scale.x + 0.02, node.scale.y + 0.02, node.scale.z + 0.02)
            node.position.y += 0.0002
        }
    }
    
    func updatePositionAndOrientationOf(_ node: SCNNode, withPosition position: SCNVector3, relativeTo referenceNode: SCNNode) {
        let referenceNodeTransform = matrix_float4x4(referenceNode.transform)
        
        // Setup a translation matrix with the desired position
        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3.x = position.x
        translationMatrix.columns.3.y = position.y
        translationMatrix.columns.3.z = position.z
        
        // Combine the configured translation matrix with the referenceNode's transform to get the desired position AND orientation
        let updatedTransform = matrix_multiply(referenceNodeTransform, translationMatrix)
        node.transform = SCNMatrix4(updatedTransform)
    }
    
    func wifiStrength() -> Double {
        let app = UIApplication.shared
        let subviews = ((app.value(forKey: "statusBar") as! NSObject).value(forKey: "foregroundView") as! UIView).subviews
        var dataNetworkItemView: UIView?
        
        for subview in subviews {
            if subview.isKind(of: NSClassFromString("UIStatusBarDataNetworkItemView")!) {
                dataNetworkItemView = subview
                break
            }
        }
    
        let dBm = (dataNetworkItemView!.value(forKey: "wifiStrengthRaw") as! NSNumber).intValue
        var strength = (Double(dBm) + 90.0) / 60.0
        if strength > 1 {
            strength = 1
        }
        return strength
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}

// https://stackoverflow.com/questions/50678671/setting-up-the-orientation-of-3d-text-in-arkit-application
class TextNode: SCNNode{
    
    var textGeometry: SCNText!
    
    /// Creates An SCNText Geometry
    ///
    /// - Parameters:
    ///   - text: String (The Text To Be Displayed)
    ///   - depth: Optional CGFloat (Defaults To 1)
    ///   - font: UIFont
    ///   - textSize: Optional CGFloat (Defaults To 3)
    ///   - colour: UIColor
    init(text: String, depth: CGFloat = 0.01, font: String = "Helvatica", textSize: CGFloat = 1, colour: UIColor) {
        
        super.init()
        
        //1. Create A Billboard Constraint So Our Text Always Faces The Camera
        let constraints = SCNBillboardConstraint()
        
        //2. Create An SCNNode To Hold Out Text
        let node = SCNNode()
        let max, min: SCNVector3
        let tx, ty, tz: Float
        
        //3. Set Our Free Axes
        constraints.freeAxes = .Y
        
        //4. Create Our Text Geometry
        textGeometry = SCNText(string: text, extrusionDepth: depth)
        
        //5. Set The Flatness To Zero (This Makes The Text Look Smoother)
        textGeometry.flatness = 0
        
        //6. Set The Alignment Mode Of The Text
        textGeometry.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        
        //7. Set Our Text Colour & Apply The Font
        textGeometry.firstMaterial?.diffuse.contents = colour
        textGeometry.firstMaterial?.isDoubleSided = true
        textGeometry.font = UIFont(name: font, size: textSize)
        
        //8. Position & Scale Our Node
        max = textGeometry.boundingBox.max
        min = textGeometry.boundingBox.min
        
        tx = (max.x - min.x) / 2.0
        ty = min.y
        tz = Float(depth) / 2.0
        
        node.geometry = textGeometry
        node.scale = SCNVector3(0.01, 0.01, 0.1)
        node.pivot = SCNMatrix4MakeTranslation(tx, ty, tz)
        
        self.addChildNode(node)
        
        self.constraints = [constraints]
        
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
