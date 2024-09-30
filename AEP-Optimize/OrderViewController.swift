//
//  OrderViewController.swift
/*
Copyright 2023 Adobe
All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in
accordance with the terms of the Adobe license agreement accompanying
it.
*/

import UIKit
import AEPCore
import AEPIdentity
import WebKit

class OrderViewController: UIViewController, WKNavigationDelegate{

    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.title = "Order Page"
    
        webView.navigationDelegate = self
        
        let url:String = "https://vadymus.github.io/ateng/at-order-confirmation/index.html?a=1&b=2"

        let startTime1 = CFAbsoluteTimeGetCurrent()
        AEPSDKManager.getUrlVariablesForWebview() { urlVariables in
            print("getUrlVariablesForWebview \(String(describing: urlVariables))")
            DispatchQueue.main.async { // load the web view on main thread with Adobe formatted url variables
                let urlWithVisitorData: URL = URL(string: url + "?" + (urlVariables ?? ""))!
                let request = NSMutableURLRequest(url: urlWithVisitorData )
                let timeElapsed1 = CFAbsoluteTimeGetCurrent() - startTime1 // Test time it took to generate URL by SDK
                print("Time elapsed for getUrlVariablesForWebview: \(timeElapsed1) s.")
                // Custom extension to sync Adobe Ids
                //self.webView.syncAdobeIdentifiersBeforeWebViewLoad(webview: self.webView)
                self.webView.load(request as URLRequest)
            }
        }
                    
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Show prefetched Target content
//            applyPrefetchedTargetOffers()
        
        // Make Analytics page view call
        MobileCore.track(state: "Second Page", data: ["customerId": "78346872782346578"])
//        AdobeMCManager.makeAnalyticsCall(forKey: "SECOND_VIEW")

    }
    
    
    func webView(_ webView: WKWebView, decidePolicyFor
           navigationAction: WKNavigationAction,
           decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void) {

        print("navigationAction \(String(describing: webView.url))")
        //link to intercept www.example.com

        // navigation types: linkActivated, formSubmitted,
        //                   backForward, reload, formResubmitted, other

        if navigationAction.navigationType == .linkActivated {
            if webView.url!.absoluteString == "http://www.example.com" {
                //do stuff

                //this tells the webview to cancel the request
                decisionHandler(.cancel)
                return
            }
        }

        //this tells the webview to allow the request
        decisionHandler(.allow)

    }
    
    
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let js1 = "const getCookieValue = (name) => (document.cookie.match('(^|;)\\s*' + name + '\\s*=\\s*([^;]+)')?.pop() || '');setTimeout(function(){ document.querySelector('#full_name_id').value=getCookieValue('s_ecid');},2000);/*setTimeout(function(){ document.querySelector('#street1_id').value=getCookieValue('mbox'); },3000);*/"
        
        let js2 = "if(document.querySelector('body > nav')){document.querySelector('body > nav').style.display='none'};"
        let js = "\(js1)\(js2)"
        self.webView.evaluateJavaScript(js) { (id, error) in
            print("didFinish navigation \(String(describing: id))")
            //print(error as Any)
        }
    }
        
}

