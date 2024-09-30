//
//  AppDelegate.swift
/*
Copyright 2023 Adobe
All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in
accordance with the terms of the Adobe license agreement accompanying
it.
*/

import UIKit

// AEP SDK imports:
import AEPCore
import AEPAssurance
import AEPEdgeIdentity
import AEPEdgeConsent
import AEPEdge
import AEPOptimize
import AEPUserProfile
import AEPIdentity
import AEPLifecycle
import AEPSignal
import AEPServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        AppTrackingService.shared.startTracking()
        
        // do initialization
        self.initAepSdks(application)
        //end initialization
            
      
            
            /* //TEST:
            AEPSDKManager.getSeededEcidFromFpid(fpid: "AEPSDKManager.FPID") { (result, error) in
                if let newEcid = result {
                    print("||==>> FPID successfully seeded a new ECID: \(String(describing: result))")
                    
                    do {
                        try AEPSDKManager.updateEcidInJSONFile(from: "com.adobe.aep.datastore", with: "com.adobe.module.identity.json", newEcid: newEcid)
                        print("||==>> Newly seeded ECID was successfully updated to \(newEcid).")
                        
                    } catch {
                        print("||==>> Error updating ECID value: \(error)")
                    }
                    
                } else if let error = error {
                    print("||==>> ECID from FPID error: \(error.localizedDescription)")
                }
                
                // do initialization
                self.initAepSdks(application)
                //end initialization
            }*/
        
        
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        AEPSDKManager.isContentPrefetched = false //make sure we prefetch content again
        AEPSDKManager.appEntryUrlParameters = [:] //clear possible values
        AppTrackingService.shared.stopTracking()
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        AppTrackingService.shared.startTracking()
        
        // Prefetch Target Locations on App Re-Entry
        AEPSDKManager.isContentPrefetched = false //clear old load
        //AEPSDKManager.prefetchLocations()
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        print("url= \(String(describing: url.absoluteString))")
        //ex: url= com.adobe.optimize://?at_preview_token=mhFIzJSF7JWb-RsnakpBqlvOU5dAZxljCIJxLpNdtiw&at_preview_index=1_1&at_preview_listed_activities_only=true&at_preview_evaluate_as_true_audience_ids=7356277
        
        // Called when the app in background is opened with a deep link.
        // Start the Assurance session and go to https://experience.adobe.com/#/@atag/data-collection/assurance
        Assurance.startSession(url: url)
        
        
        
        AEPSDKManager.appEntryUrlParameters = [:]
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        if let queryItems = components.queryItems {
            for item in queryItems {
                AEPSDKManager.appEntryUrlParameters[item.name] = item.value!
            }
        }
        print("URL is parsed: \(AEPSDKManager.appEntryUrlParameters)")
        
        //Assurance.startSession(url: url)
        
        // AEP SDK deep linking/preview
        if url.scheme == "com.adobe.optimize"{
            
            //AEPTarget.setPreviewRestartDeeplink(url) // preview selections
            MobileCore.collectLaunchInfo(["adb_deeplink":url.absoluteString]) // preview mode
            print("in application:app:url:options \(url)")
            return true
        }
        return false
    }
    
    func initAepSdks (_ application: UIApplication) {
        
        let launchIds = [
            "22bf1a13013f/f5dd2c39eb71/launch-8fbe6b4d2f3e-development", //EE Dev
            "164e49a27fff/a3823dd6bd3f/launch-cb0342285348-development"  //AGS300 Dev (Optimize)
        ]
        
        DispatchQueue.main.async {
            
            // AEP SDK config:
            MobileCore.setLogLevel(.debug)
            let appState = application.applicationState
            let extensions = [
                Assurance.self,
                AEPEdgeIdentity.Identity.self,
                AEPIdentity.Identity.self,
                Consent.self,
                Edge.self,
                Optimize.self,
                UserProfile.self,
                Lifecycle.self,
                Signal.self
            ]
            MobileCore.registerExtensions(extensions, {
                MobileCore.configureWith(appId: launchIds[1])
                
                //Indicates how long, in seconds, Places membership information for the device will remain valid. Default value of 3600 (seconds in an hour).
                // [N/A???] MobileCore.updateConfigurationWith(configDict: ["places.membershipttl" : 1800])
                
                // set this to false or comment it when deploying to TestFlight (default is false),
                // set this to true when testing on your device.
                MobileCore.updateConfigurationWith(configDict: ["messaging.useSandbox": true])
                if appState != .background {
                    MobileCore.lifecycleStart(additionalContextData: ["myCustomLifecycle": "see app codebase"])
                    // for demo purposes, print Traget identifiers
                    /////AEPSDKManager.collectTargetIdentifiers()
                    
                    // Prefetch Target Locations on Initial App Entry
                    // Note: we will also prefetch on app re-entry, see applicationWillEnterForeground
                    AEPSDKManager.prefetchScopes()
                }
                // assume unknown, adapt to your needs.
                MobileCore.setPrivacyStatus(.unknown)
            })
        }
    }
    


}

