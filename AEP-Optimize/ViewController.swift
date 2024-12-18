//
//  ViewController.swift
/*
Copyright 2023 Adobe
All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in
accordance with the terms of the Adobe license agreement accompanying
it.
*/

import UIKit

// AEP SDK imports:
import AEPOptimize
import AEPCore

let notificationTargetUpdate = Notification.Name.init(rawValue: "notificationTargetUpdate")

class ViewController: UIViewController, NSURLConnectionDelegate {
    
    @IBOutlet weak var homeImage: UIImageView?
    @IBOutlet weak var nextPageButton: UIButton!
    @IBOutlet weak var trackActionButton: UIButton!
    @IBOutlet weak var bannerView: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var accountLoginButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        print("in viewDidLoad")
        self.title = "Home"
        
        // example using events
        MobileCore.registerEventListener(type: EventType.edge, source: EventSource.notification, listener: { event in
            print("MobileCore event for edge notification: \(event)")
        })
        
        MobileCore.registerEventListener(type: EventType.edge, source: EventSource.personalizationDecisions, listener: { event in
            print("MobileCore event for edge decisions: \(event)")
        })
        
        bannerView.addBlurEffectToView()
        trackActionButton.addBlurEffect()
        nextPageButton.addBlurEffect()
        
    }
    
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("in viewWillAppear")
        
        if AEPSDKManager.userMembershipLevel == "" {
            accountLoginButton.setTitle("Login",for: .normal)
        }else{
            accountLoginButton.setTitle("Account",for: .normal)
        }

        // Apply Prefetched Target Offers
        prehideTestedContent(timeout: 5)
        renderPrefetchedPropositions()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(renderPrefetchedPropositions),
                                               name: .propositionsPrefetched,
                                               object: nil)

        
        MobileCore.track(state: "Home Page", data: [
                                                    "myCustomVar": "mobile training",
                                                    //"&&referrer":"https://vadym.com/hello",
                                                    "&&r":"https://site.com/hello",
//                                                    "bb.screenName":"Bus Booking View screen",
//                                                    "bb.key1":"test value1",
//                                                    "bb.key2":"test value2"
                                                   ])

        
        // TEST get all IDs
        MobileCore.getSdkIdentities { (str, err) in
            if (err == nil) {
                print("\nSuccess - AEPCore.getSDKIdentities: \(String(describing: str)) \n\n")
            } else {
                print("Error - AEPCore.getSDKIdentities: string:\(String(describing: str)) error:\(String(describing: err))")
            }
        }

    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
//        let delay = DispatchTimeInterval.seconds(3)
//        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
//            self.simulateSimultaneousPersonalizationCalls()
//        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: .propositionsPrefetched, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @IBAction func didTapButtonAction(sender:UIButton!) {
        print("Button Clicked")
        //let aaData = AdobeMCManager.getAnalyticsData(forKey: "HOME", andSubKey: "analyticsActionData")
        MobileCore.track(action: "Home Button Action", data: nil)
    }
    
    
    
    private func connection(connection: NSURLConnection!, didReceiveResponse response: URLResponse!) {
        print("RESPONSE IS \(String(describing: response))")
    }
    
    // MARK: Segues
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "LoginViewController"){
        
            let lvc = segue.destination as? LoginViewController
            lvc?.viewControllerRef = self
            
        }
    }
    
    
    
}

// MARK: Target Implementation

// AEP SDK Displaying Target Offers

extension ViewController{
    
    // Pre-hides personalized content
    func prehideTestedContent(timeout:Double){
        self.homeImage?.alpha = 0
        self.messageLabel?.alpha = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            self.homeImage?.alpha = 1
            self.messageLabel?.alpha = 1
        }
    }
    
    /**
     * Applies Target Offers that were prefetched on app entry; triggers Notifications calls for prefetched content
     * Note: if prefetched content failed to load due to offline mode, then this will trigger an Execute call
     */
    @objc func renderPrefetchedPropositions(){

        //print("optimize-test: will be calling props")
        if AEPSDKManager.isContentPrefetched{
            
            // Change banner
            var decisionScopes = [DecisionScope]()
            for scope in ["optimize-test-2"
                //"sdk-demo-1","sdk-demo-2"
            //              ,"pref-a4t-location-1","pref-a4t-location-2","pref-a4t-location-3"
            ]{
                decisionScopes.append(DecisionScope(name: scope))
            }
            Optimize.getPropositions(for: decisionScopes) { propositionsDict, error in
                //print("prefetched content (sdk-demo-1) \(String(describing: propositionsDict))")
                if error == nil, let propositions = propositionsDict{
                    
                    print("optimize-test: inside getPropositions. about to call optimize-test scope with props \(propositions)")
                    
                    if let proposition:OptimizeProposition = propositions[DecisionScope(name: "optimize-test-2")],
                       !proposition.offers.isEmpty{
                        proposition.offers.forEach{ offer in
                            offer.displayed() // Notification to Edge
                            // Process Target response
                            print("optimize-test: proposition offer content: \(String(describing: offer.content))")
                            DispatchQueue.main.async {
                                
                                if let data = offer.content.data(using: .utf8) {
                                    do {
                                        let attributedString = try NSAttributedString(
                                            data: data,
                                            options: [
                                                .documentType: NSAttributedString.DocumentType.html,
                                                .characterEncoding: String.Encoding.utf8.rawValue
                                            ],
                                            documentAttributes: nil
                                        )
                                        
                                        self.messageLabel.attributedText = attributedString
                                        
                                    } catch {
                                        print("Failed to create attributed string: \(error)")
                                    }
                                }
                                
                            }
                        }
                    }
                    
                    // Update Home page image
                    if let image = AEPSDKManager.getValueFromPropositions(for: "image", decisionScope: "sdk-demo-1", propositions: propositions){
                        DispatchQueue.main.async {
                            switch image{
                                case "adobe": self.homeImage?.image = UIImage(named: "adobe")
                                case "iphone": self.homeImage?.image = UIImage(named: "iphone")
                                case "galaxy": self.homeImage?.image = UIImage(named: "galaxy")
                                default: print ("showing default image because response is: \(image)")
                            }
                        }
                    }
                    
                    // Change message on Home page
                    if let message = AEPSDKManager.getValueFromPropositions(for: "message", decisionScope: "sdk-demo-2", propositions: propositions),
                        message.count > 0 {
                            print("prefetched message \(message)")
                            DispatchQueue.main.async {
                                self.messageLabel.text = message
                            }
                    }
//                    // Change message on Home page
//                    if let message = AEPSDKManager.getValueFromPropositions(for: "message", decisionScope: "color-blue", propositions: propositions),
//                        message.count > 0 {
//                            print("prefetched executing message \(message)")
////                            DispatchQueue.main.async {
////                                self.messageLabel.text = message
////                            }
//                    }
                    
                    // Update Home page image
                    if let bannerValue = AEPSDKManager.getValueFromPropositions(for: "banner", decisionScope: "sdk-demo-5", propositions: propositions),
                        bannerValue.count > 0 {
                            print("Target message \(bannerValue)")
                            DispatchQueue.main.async {
                                guard let bannerUrl = bannerValue as String?, bannerUrl.count > 0 else {
                                        print("Hi there)")
                                        return
                                }
                                self.homeImage?.load(url: URL(string: bannerUrl)!)
                            }
                    }
                    
                    // Read Home page exp
                    if let abTestValue = AEPSDKManager.getValueFromPropositions(for: "exp", decisionScope: "sdk-demo-6", propositions: propositions),
                       abTestValue.count > 0 {
                            print("Target A/B exp is: \(abTestValue)")
                            
                    }
                   
                }
                
                // Reveal pre-hidden elements
                DispatchQueue.main.async {
                    self.homeImage?.alpha = 1
                    self.messageLabel?.alpha = 1 // reveal pre-hidden personalized content
                }
            }
        }
    }
    
    /**
     * Experiment for firing multiple calls to the Edge at the same time
     */
    func simulateSimultaneousPersonalizationCalls(){
        
        struct ExecutionBlock {
            let order: Int
            let delayMS: Int
            let scope: String
            let color: String
        }
        let executionBlocks: [ExecutionBlock] = [
            ExecutionBlock(order: 1, delayMS: 0, scope: "color-yellow", color: "yellow"),
            ExecutionBlock(order: 2, delayMS: 0, scope: "color-blue", color: "blue"),
            ExecutionBlock(order: 3, delayMS: 0, scope: "color-red", color: "red"),
            ExecutionBlock(order: 4, delayMS: 100, scope: "color-yellow", color: "yellow"),
            ExecutionBlock(order: 5, delayMS: 100, scope: "color-blue", color: "blue"),
            ExecutionBlock(order: 6, delayMS: 100, scope: "color-red", color: "red"),
            ExecutionBlock(order: 7, delayMS: 200, scope: "color-yellow", color: "yellow"),
            ExecutionBlock(order: 8, delayMS: 200, scope: "color-blue", color: "blue"),
            ExecutionBlock(order: 9, delayMS: 200, scope: "color-red", color: "red"),
            ExecutionBlock(order: 10, delayMS: 300, scope: "color-yellow", color: "yellow")
        ]
        for block in executionBlocks {
            let delay = DispatchTimeInterval.milliseconds(block.delayMS)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                DispatchQueue.global().async {
                    print("\(block.order). Executing block for scope '\(block.scope)' delayed by \(block.delayMS)")
                    let startTime = CFAbsoluteTimeGetCurrent()
                    Optimize.updatePropositions(for: [DecisionScope(name: block.scope)],
                                                withXdm: nil,
                                                andData: ["__adobe": ["target": ["color" : block.color]]])
                    Optimize.getPropositions(for: [DecisionScope(name: block.scope)]) { propositionsDict, error in
                        if error == nil, let propositions = propositionsDict{
                            if let message = AEPSDKManager.getValueFromPropositions(for: "message", decisionScope: block.scope, propositions: propositions){
                                DispatchQueue.main.async {
                                    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                                    print("\(block.order).  Retrieved \(message) after executing '\(block.scope)' within \(timeElapsed)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}

extension UIButton
{
    func addBlurEffect()
    {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blur.frame = self.bounds
        blur.isUserInteractionEnabled = false
        self.insertSubview(blur, at: 0)
        if let imageView = self.imageView{
            self.bringSubview(toFront: imageView)
        }
    }
}
extension UIView
{
    func addBlurEffectToView()
    {
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = self.bounds
        
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight] // for supporting device rotation
        //self.addSubview(blurEffectView)
        self.insertSubview(blurEffectView, at: 0)
    }
}
extension UIImageView {
    func load(url: URL) {
        DispatchQueue.global().async { [weak self] in
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.image = image
                        self?.alpha = 1
                    }
                }
            }
        }
    }
}



    
    
