//
//  SecondViewController.swift
/*
Copyright 2023 Adobe
All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in
accordance with the terms of the Adobe license agreement accompanying
it.
*/

import UIKit
import AEPCore
import AEPOptimize

class LoginViewController: UIViewController {
    
    @IBOutlet weak var messageView: UITextView!
    @IBOutlet weak var trackActionButton: UIButton!
    @IBOutlet weak var useNameInput: UITextField!
    @IBOutlet weak var userPasswordInput: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var accountMessage: UITextView!
    @IBOutlet weak var logoutButton: UIButton!
    
    open var viewControllerRef:ViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if AEPSDKManager.userMembershipLevel == "" {
            self.title = "Login"
            toggleLoginControls(isLoggedIn: false)
        }else{
            self.title = "Account"
            toggleLoginControls(isLoggedIn: true)
        }
    
        messageView.addBlurEffectToView()
        trackActionButton.addBlurEffect()
        logoutButton.addBlurEffect()
        accountMessage.addBlurEffectToView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Apply Prefetched Target Offers
        renderPrefetchedPropositions()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(renderPrefetchedPropositions),
                                               name: .propositionsPrefetched,
                                               object: nil)
        
        // Make Analytics page view call
        MobileCore.track(state: "Second Page", data: ["customerId": "78346872782346578"])

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        NotificationCenter.default.removeObserver(self, name: .propositionsPrefetched, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func didTapCloseControllerButton(sender: AnyObject?){
        self.dismiss(animated: true) {
            //
        }
    }
    
    @IBAction func didTapLogin(sender:UIButton!) {
        print("Button Login")
        
        
        AEPSDKManager.setIdentifiersAfterUserAuthentication()
        
        // Prefetch content again
        AEPSDKManager.isContentPrefetched = false
        AEPSDKManager.prefetchScopes()
        
        toggleLoginControls(isLoggedIn: true)
        
        MobileCore.track(action: "Login View Login Button Action", data: nil)
    }
    
    @IBAction func didTapLogout(sender:UIButton!) {
        print("Button Logout")
        AEPSDKManager.clearIdentifiersAfterUserLogout()
        
        // Prefetch content again
        AEPSDKManager.isContentPrefetched = false
        AEPSDKManager.prefetchScopes()
        
        toggleLoginControls(isLoggedIn: false)
        MobileCore.track(action: "Login View Logout Button Action", data: nil)
    }
    
    func toggleLoginControls(isLoggedIn:Bool){
        if isLoggedIn == false{
            useNameInput.isHidden = false
            userPasswordInput.isHidden = false
            loginButton.isHidden = false
            accountMessage.isHidden = true
            logoutButton.isHidden = true
            self.viewControllerRef?.accountLoginButton.setTitle("Login",for: .normal)
                
        }else{
            useNameInput.isHidden = true
            userPasswordInput.isHidden = true
            loginButton.isHidden = true
            accountMessage.isHidden = false
            logoutButton.isHidden = false
            self.viewControllerRef?.accountLoginButton.setTitle("Account",for: .normal)
        }
    }
}

// MARK: Target Implementation

extension LoginViewController{
    
    @objc func renderPrefetchedPropositions(){
        print("in ProductTableViewController.renderPrefetchedPropositions")
        
        
        //MobileCore.registerEventListener(type: EventType.edge, source: EventSource.personalizationDecisions, listener: { event in
            //print("MobileCore event for edge decisions: \(event)")
        if AEPSDKManager.isContentPrefetched{
            
            
            
            // Change banner
            var decisionScopes = [DecisionScope]()
            for scope in ["sdk-demo-2"]{
                decisionScopes.append(DecisionScope(name: scope))
            }
            Optimize.getPropositions(for: decisionScopes) { propositionsDict, error in
                print("prefetched content (sdk-demo-2) \(String(describing: propositionsDict))")
                if error == nil, let propositions = propositionsDict{
                    
                    // Update massage
                    if let message = AEPSDKManager.getValueFromPropositions(for: "message", decisionScope: "sdk-demo-2", propositions: propositions),
                       message.count > 0{
                        print("Target message \(message)")
                        DispatchQueue.main.async {
                            self.messageView.text = message
                        }
                    }
                    
                }
                
            }
        }
        //})

    }
    
    
    
}

