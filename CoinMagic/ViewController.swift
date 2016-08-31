//
//  ViewController.swift
//  CoinMagic
//
//  Created by Fangchen Huang on 2016-08-29.
//  Copyright © 2016 Paul H. All rights reserved.
//

import UIKit
import CoreMotion
import AudioToolbox

class ViewController: UIViewController {
    
    let motionManager = CMMotionManager()
    var panRecognizer: UIPanGestureRecognizer!
    
    lazy var coinImageView: CircleImageView = {
        let coinImage = UIImage(named: "coin")
        let imageView = CircleImageView(frame: CGRect(x: 0, y: 0, width: 140, height: 140))
        imageView.image = coinImage
        imageView.layer.cornerRadius = imageView.frame.size.width / 2
        
        return imageView
    }()
    
    lazy var collisionSoundId: SystemSoundID? = {
        guard let soundURL = NSBundle.mainBundle().URLForResource("collision", withExtension: "wav") else { return nil }
        var id: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(soundURL, &id)
        
        return id
    }()
    
    lazy var physics: UIDynamicAnimator = {
        return UIDynamicAnimator(referenceView: self.view)
    }()
    let gravity = UIGravityBehavior()
    let collider = UICollisionBehavior()

    // MARK: - UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initializes coin image and add to view
        view.addSubview(coinImageView)
        coinImageView.hidden = true
        coinImageView.userInteractionEnabled = true
        
        // UIDynamics setup
        collider.addItem(coinImageView)
        collider.collisionDelegate = self
        collider.translatesReferenceBoundsIntoBoundary = true // Prevents view from moving outside of the screen
        gravity.addItem(coinImageView)
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        coinImageView.addGestureRecognizer(panRecognizer)

        ObserveDeviceMotion()
    }
    
    override func viewDidLayoutSubviews() {
        coinImageView.center = view.center
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }

}

// MARK: - Private Functions
private extension ViewController {
    
    @objc func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard coinImageView.hidden == false else { return }
        
        if gestureRecognizer.state == .Began || gestureRecognizer.state == .Changed {
            stopPhysics()
            
            // http://blog.apoorvmote.com/uipangesturerecognizer-to-make-draggable-uiview-in-ios-swift/
            let translation = gestureRecognizer.translationInView(view)
            guard let pannedView = gestureRecognizer.view else { return }
            pannedView.center = CGPointMake(pannedView.center.x + translation.x, pannedView.center.y + translation.y)
            gestureRecognizer.setTranslation(CGPointMake(0,0), inView: view)
        }
        if gestureRecognizer.state == .Ended {
            if isSubViewOutOfBound(view: coinImageView) {
                stopPhysics() // Must stop UIDynamicAnimator before making changes to view frame

                coinImageView.hidden = true
                coinImageView.center = view.center
            }
            else {
                startPhysics()
            }
        }
    }
    
    func startPhysics() {
        physics.addBehavior(collider)
        physics.addBehavior(gravity)
    }
    
    func stopPhysics() {
        physics.removeAllBehaviors()
    }
}

// MARK: - Shake Detection
extension ViewController {
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func motionBegan(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == .MotionShake {
            coinImageView.hidden = !coinImageView.hidden

            if coinImageView.hidden {
                stopPhysics()                
                coinImageView.center = view.center
            }
            else {
                startPhysics()
            }
        }
    }
}

// MARK: - Motion Detection
extension ViewController {

    func isSubViewOutOfBound(view subView: UIView) -> Bool {
        let subViewWidth = subView.frame.size.width
        let subViewHeight = subView.frame.size.height

        let subViewLeftBound = subView.frame.origin.x
        let subViewRightBound = subViewLeftBound + subViewWidth
        let subViewTopBound = subView.frame.origin.y
        let subViewBottomBound = subViewTopBound + subViewHeight

        let viewLeftBound = self.view.bounds.origin.x
        let viewRightBound = viewLeftBound + self.view.bounds.size.width
        let viewTopBound = self.view.bounds.origin.y
        let viewBottomBound = viewTopBound + self.view.bounds.size.height

        return subViewLeftBound < viewLeftBound
            || subViewRightBound > viewRightBound
            || subViewTopBound < viewTopBound
            || subViewBottomBound > viewBottomBound
    }
    
    func ObserveDeviceMotion() {
        if motionManager.deviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01
            
            // Dispatches device motion updates on its own queue so that main queue is freed up
            let motionQueue = NSOperationQueue()
            motionManager.startDeviceMotionUpdatesToQueue(motionQueue, withHandler: { (motion, error) in
                guard error == nil else {
                    print(error)
                    return
                }
                guard let gravity = motion?.gravity else { return }
                
                let x = CGFloat(gravity.x)
                let y = CGFloat(gravity.y)
                let vector = CGVector(dx: x, dy: -y)
                
                NSOperationQueue.mainQueue().addOperationWithBlock({
                    self.gravity.gravityDirection = vector
                })
            })
        }
    }
}

// MARK: - UICollisionBehaviorDelegate
extension ViewController: UICollisionBehaviorDelegate {
    
    func collisionBehavior(behavior: UICollisionBehavior, beganContactForItem item: UIDynamicItem, withBoundaryIdentifier identifier: NSCopying?, atPoint p: CGPoint) {
        
        if let collisionSoundId = self.collisionSoundId {
            AudioServicesPlaySystemSound(collisionSoundId)
        }
    }
}

// MAKR: - CircleImageView
class CircleImageView: UIImageView {
    
    // Must override to make imageView roll along the screen boundaries
    override var collisionBoundsType: UIDynamicItemCollisionBoundsType {
        return .Ellipse
    }
}

