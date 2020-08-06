# MLKit-ARKit
This simple project detects objects using Firebase ML Kit and tags them in with 3D labels in Augmented Reality.

Based on: [CoreML-in-ARKit](https://github.com/hanleyweng/CoreML-in-ARKit)

![Demo gif](https://media.giphy.com/media/5dUxUy8VxfAfwJSD6I/giphy.gif)

[Demo Video](https://photos.app.goo.gl/RWdBvMcn2ASmkWaPA)

Language: Swift 4.0

Content Technology: SceneKit, Firebase ML Kit

Note: SceneKit can achieve a 60 FPS on iPhone7+ - though when it gets hot, it'll drop to 30 FPS.

## Status

![Status: Archived](https://img.shields.io/badge/Status-Archived-red)

This sample is no longer actively maintained and is left here for reference only.

## Footnotes

- SceneKit Text Labels are expensive to render. Too many polygons (too much text, smoothness, characters) - can cause crashes. In future, SpriteKit would be more efficient for text-labels.

- Whilst ARKit's FPS , is displayed - ML Kit's speed is not. However, it does appear sufficiently fast for real-time ARKit applications.

- Placement of the label is simply determined by the raycast screen centre-point to a ARKit feature-point. This could be altered for more stable placement.

## Building Blocks (Overview)

### Get ML Kit running in real time in ARKit

- What we do differently here is we're using ARKit's ARFrame as the image to be fed into ML Kit.

```
let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
```

- We also use Threading to continuously run requests to ML Kit in realtime, and without disturbing ARKit / SceneView

```
let dispatchQueueML = DispatchQueue(label: "dispatchqueueml")
...
loopMLKitUpdate() // on viewLoad
...
func loopMLKitUpdate() {
    dispatchQueueML.async {
        // 1. Run Update.
        self.updateMLKit()
        // 2. Loop this function.
        self.loopMLKitUpdate()
    }
}
```

### Add 3D Text

- Add a Tap Gesture.
- On Tap. Get the raycast centre point, translating it to appropriate coordinates.
- Render 3D text at that location. Use the most likely object.
