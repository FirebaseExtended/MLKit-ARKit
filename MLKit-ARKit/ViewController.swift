//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SceneKit
import ARKit
import Firebase

class ViewController: UIViewController {

  // SCENE
  @IBOutlet var sceneView: ARSCNView!
  let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
  var latestPrediction : String = "…" // a variable containing the latest ML Kit prediction

  // ML Kit
  private lazy var vision = Vision.vision()
  let dispatchQueueML = DispatchQueue(label: "dispatchqueueml", autoreleaseFrequency: .workItem) // A Serial Queue
  @IBOutlet weak var debugTextView: UITextView!

  override func viewDidLoad() {
    super.viewDidLoad()

    // Show statistics such as fps and timing information
    sceneView.showsStatistics = true

    // Create a new scene
    let scene = SCNScene()

    // Set the scene to the view
    sceneView.scene = scene

    // Enable Default Lighting - makes the 3D text a bit poppier.
    sceneView.autoenablesDefaultLighting = true

    //////////////////////////////////////////////////
    // Tap Gesture Recognizer
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
    view.addGestureRecognizer(tapGesture)

    // Begin Loop to Update ML Kit
    loopMLKitUpdate()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    // Enable plane detection
    configuration.planeDetection = .horizontal

    // Run the view's session
    sceneView.session.run(configuration)
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // Pause the view's session
    sceneView.session.pause()
  }

  // MARK: - Status Bar: Hide
  override var prefersStatusBarHidden : Bool {
    return true
  }

  // MARK: - Interaction

  @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
    // HIT TEST : REAL WORLD
    // Get Screen Centre
    let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)

    let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.

    if let closestResult = arHitTestResults.first {
      // Get Coordinates of HitTest
      let transform : matrix_float4x4 = closestResult.worldTransform
      let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)

      // Create 3D Text
      let node : SCNNode = createNewBubbleParentNode(latestPrediction)
      sceneView.scene.rootNode.addChildNode(node)
      node.position = worldCoord
    }
  }

  func createNewBubbleParentNode(_ text : String) -> SCNNode {
    // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.

    // TEXT BILLBOARD CONSTRAINT
    let billboardConstraint = SCNBillboardConstraint()
    billboardConstraint.freeAxes = SCNBillboardAxis.Y

    // BUBBLE-TEXT
    let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
    if let visionImage = createVisionImage() {
        vision.cloudImageLabeler().process(visionImage) { labels, error in
        guard error == nil, let labels = labels, !labels.isEmpty else { return }
        bubble.string = labels[0].text
      }
    }
    var font = UIFont(name: "Futura", size: 0.15)
    font = font?.withTraits(traits: .traitBold)
    bubble.font = font
    bubble.alignmentMode = kCAAlignmentCenter
    bubble.firstMaterial?.diffuse.contents = UIColor.orange
    bubble.firstMaterial?.specular.contents = UIColor.white
    bubble.firstMaterial?.isDoubleSided = true
    // bubble.flatness // setting this too low can cause crashes.
    bubble.chamferRadius = CGFloat(bubbleDepth)

    // BUBBLE NODE
    let (minBound, maxBound) = bubble.boundingBox
    let bubbleNode = SCNNode(geometry: bubble)
    // Centre Node - to Centre-Bottom point
    bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
    // Reduce default text size
    bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)

    // CENTRE POINT NODE
    let sphere = SCNSphere(radius: 0.005)
    sphere.firstMaterial?.diffuse.contents = UIColor.cyan
    let sphereNode = SCNNode(geometry: sphere)

    // BUBBLE PARENT NODE
    let bubbleNodeParent = SCNNode()
    bubbleNodeParent.addChildNode(bubbleNode)
    bubbleNodeParent.addChildNode(sphereNode)
    bubbleNodeParent.constraints = [billboardConstraint]

    return bubbleNodeParent
  }

  // MARK: - ML Kit Vision Handling

  func loopMLKitUpdate() {
    // Continuously run ML Kit whenever it's ready. (Preventing 'hiccups' in Frame Rate)
    dispatchQueueML.async {
      // 1. Run Update.
      self.updateMLKit()

      // 2. Loop this function.
      self.loopMLKitUpdate()
    }
  }

  func updateMLKit() {
    let visionImage = VisionImage.init(image: sceneView.snapshot())
    let group = DispatchGroup()
    let options = VisionOnDeviceImageLabelerOptions()
    options.confidenceThreshold = 0.7
    group.enter()
    vision.onDeviceImageLabeler(options: options).process(visionImage) { features, error in
      defer { group.leave() }
      guard error == nil, let features = features, !features.isEmpty else {
        let errorString = error?.localizedDescription ?? "detectionNoResultsMessage"
        print("On-Device label detection failed with error: \(errorString)")
        return
      }

      // Get Classifications
      let classifications = features
        .map { feature -> String in
            "\(feature.text) - \(feature.confidence ?? 0)" }
        .joined(separator: "\n")

      DispatchQueue.main.async {
        // Display Debug Text on screen
        var debugText:String = ""
        debugText += classifications
        self.debugTextView.text = debugText

        // Store the latest prediction
        var objectName:String = "…"
        objectName = classifications.components(separatedBy: "-")[0]
        objectName = objectName.components(separatedBy: ",")[0]
        self.latestPrediction = objectName

      }
    }
    group.wait()
  }
}

extension UIFont {
  // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
  func withTraits(traits:UIFontDescriptorSymbolicTraits...) -> UIFont {
    let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptorSymbolicTraits(traits))
    return UIFont(descriptor: descriptor!, size: 0)
  }
}
