//
//  AEPSDKManager.swift
/*
Copyright 2024 Adobe
All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in
accordance with the terms of the Adobe license agreement accompanying
it.
*/

import Foundation
import AEPOptimize
import AEPCore
import AEPUserProfile
import AEPEdgeIdentity
import WebKit
import SwiftyJSON
import AEPEdge

enum PageName {
    case GlobalPage
    case HomePage
    case LoginPage
    case ProductsPage
    case OrderPage
}

extension Notification.Name {
    static let propositionsPrefetched = Notification.Name("propositionsPrefetched")
}

struct AEPSDKManager {
    
    static var decisionScopesToPrefetch = [
        //DecisionScope(name: "sdk-demo-1"),///XT activity "Mobile AEP SDK - Prefetch POC - 1": delivers JSON offer with an image, targets AAM audience or falls back to All Visitors
        //DecisionScope(name: "sdk-demo-2"),///XT activity "Mobile AEP SDK - Prefetch POC - 2": delivers JSON offer with a message, targets AAM audience or falls back to All Visitors
        ///DecisionScope(name: "sdk-demo-3"),//temporarily test 3 A4T with prefetched JSON offers (named "Mobile AEP SDK - Pref A4T A/B POC - Part 1/2/3")
        /*DecisionScope(name: "pref-a4t-location-1"),
        DecisionScope(name: "pref-a4t-location-2"),
        DecisionScope(name: "pref-a4t-location-3")*/
//        DecisionScope(name: "sdk-demo-6") // A/B activity 
        DecisionScope(name: "optimize-test"),
        DecisionScope(name: "optimize-test-2")
    ] as [DecisionScope]
    static var isContentPrefetched = false
    static var userMembershipLevel = "" // <empty>, gold, or platinum
    static var appEntryUrlParameters = [String:String]()
    
    /**
     * Prefetches decision scopes. Ideally to be called on initial app load, app reload, authentication, purchase,
     * and any major events to fetch fresh content
     */
    static func prefetchScopes () {
        print("in prefetchLocations")
        
        // experiment method to load scopes from tag rule
        getPrefetchLocationsFromLaunchRule { newLocations in
            //here you can add more scopes to fetch if needed
            print("newLocations \(newLocations)")
        }
        
        // example of getting AEP identifiers
        collectAEPIdentifiers { resultDict in
            if let locationHint = resultDict["locationHint"], 
                let ecid = resultDict["ecid"] {
                print("Location Hint: \(locationHint), ECID: \(ecid)")
            } else {
                print("Error fetching AEP Identifiers")
            }
        }

        
        Optimize.clearCachedPropositions()
        //Optimize.updatePropositions(for: decisionScopesToPrefetch, withXdm: getXdmData(forKey: .GlobalPage))
        
        print("optimize-test: will prefetch now")
        
        Optimize.updatePropositions(for: decisionScopesToPrefetch, withXdm: getXdmData(forKey: .GlobalPage), andData: [:], { decisionPropositions, error in
            /// Notify all listeners when content arrives. Safe to call `getPropositions` even if call is in progress as there are internal SDK queues waiting for call to be done
            
            print("optimize-test: did prefetch now")
            
            isContentPrefetched = true
            NotificationCenter.default.post(name: .propositionsPrefetched, object: nil)
        })
            
            
        
        
    }

    
    /**
     * Attempt to retrieve decision scopes defined in a Data Collection Tag Rule
     * This feature loading scopes from Data Collection Tag helps to eliminate a new app release to the AppStore when scopes must be added/removed
     */
    static func getPrefetchLocationsFromLaunchRule (completion: @escaping ([String]) -> Void){
        var result = [String]()
        /// Attempt to retrieve decision scopes defined in Data Collection Tag rule set as a Profile attrubite
        /// It is a workaround for now to use Profile attributes as a storage. Ideally, we have a new feature for this

        UserProfile.getUserAttributes(attributeNames: ["DecisionScopes"]) { attributes, error in
            if error != .none {
                print("getPrefetchLocationsFromLaunchRule error \(String(describing: error.localizedDescription))")
                completion(result)
            }else{
                print("getPrefetchLocationsFromLaunchRule attributes: \(String(describing: attributes))")
                if let rawLocations = attributes?["DecisionScopes"] as? String {
                    if rawLocations.count > 0 {
                        let newLocations = rawLocations.components(separatedBy: "|")
                        if newLocations.count > 0 {
                            //result.append(contentsOf: newLocations)
                        }
                    }
                }
                completion(result)
            }
        }
    }


    static func getXdmData (forKey key:PageName) -> [String:Any]{
        
        let identityMap = IdentityMap()
        identityMap.add(item: IdentityItem(id: "B1207C2E-B809-45E3-8F98-070CD17CD12A", authenticatedState: .ambiguous, primary: false), withNamespace: "FPID")
        Identity.updateIdentities(with: identityMap)

        
        // Create Experience Event from dictionary:
        var xdmData : [String: Any] = ["eventType" : "SampleXDMEvent",
                                      "sample": "data"]
        let experienceEvent = ExperienceEvent(xdm: xdmData)
        if userMembershipLevel != ""{
            xdmData["type"] = "gold"
        }
        switch key {
            case PageName.GlobalPage:
                xdmData["page"] = "GlobalPage"
            case PageName.HomePage:
                xdmData["page"] = "HomePage"
            case PageName.LoginPage:
                xdmData["page"] = "LoginPage"
            case PageName.ProductsPage:
                xdmData["page"] = "ProductsPage"
            case PageName.OrderPage:
                xdmData["page"] = "OrderPage"
        }
        /*//send the Experience Event and handle the Edge Network response onComplete
        Edge.sendEvent(experienceEvent: experienceEvent) { (handles: [EdgeEventHandle]) in
          // Handle the Edge Network response
        }*/
        return xdmData
    }
    
    /**
     * Extracts a value for key and scope from propositions. It sends a notification to AEP to alert the content was seen. Feel free to customize as needed
     */
    static func getValueFromPropositions(for key:String,
                                         decisionScope:String,
                                         propositions:[DecisionScope : OptimizeProposition]) -> String?{
        var result:String? = nil
        
        if let proposition:OptimizeProposition = propositions[DecisionScope(name: decisionScope)],
           !proposition.offers.isEmpty{
        
            print("proposition analyticsToken \(String(describing: (proposition.scopeDetails["characteristics"] as! [String: Any])["analyticsToken"]))")
            
            proposition.offers.forEach{ offer in

                offer.displayed() // Notification to Edge
                
                // Process Target response
                print("proposition offer content: \(String(describing: offer.content))")
                if let data = offer.content.data(using: .utf8){
                    do {
                        if let contentAsJson = try JSONSerialization.jsonObject(with: data, options : []) as? [String:Any]
                        {
                            if let jsonValue:String = contentAsJson[ key ] as? String{
                                print("proposition offer value: \(String(describing: jsonValue))")
                                result = jsonValue
                            }
                            
                        } else {
                            print("Target bad JSON")
                        }
                    } catch let error as NSError {
                        print(error)
                    }
                }
            }
        }
        
        return result
        
    }
        
    


        
    
    
    static func setIdentifiersAfterUserAuthentication(){
        
        let _ : [String: String] = ["customerID":"781456718571634714756",
                                              "anotherID":"907862348792346"];
        
        // One way to add Customer IDs
//        let identifiers : [String: String] = ["guid":"12345","hhid":"67890","secretid":"1234567890"];
//        Identity.syncIdentifiers(identifiers, authentication: .authenticated)
        
        // Fix order by setting to empty
        /*ACPIdentity.syncIdentifier("guid", identifier: "", authentication: .authenticated)
        ACPIdentity.syncIdentifier("hhid", identifier: "", authentication: .authenticated)
        ACPIdentity.syncIdentifier("secretid", identifier: "", authentication: .authenticated)*/
        
        // Set IDs - this is a better way to add multiple IDs one by one because the order persists, which is important for Target (Target uses the first ID on a list as identifier)
//        Identity.syncIdentifier(identifierType: "guid", identifier: "12345", authenticationState: .authenticated)
//        Identity.syncIdentifier(identifierType: "hhid", identifier: "67890", authenticationState: .authenticated)
//        Identity.syncIdentifier(identifierType: "secretid", identifier: "1234567890", authenticationState: .authenticated)
        
        // Check Customer IDs
//        Identity.getIdentifiers { retrievedVisitorIds, error in
//            for visitorId in retrievedVisitorIds ?? [] {
////                print("visitorId type \(String(describing: visitorId.idType))")
//                print("TODO: visitorId type \(String(describing: visitorId))")
//            }
//        }
        
        userMembershipLevel = "gold"
    }
    
    static func clearIdentifiersAfterUserLogout(){
        
//        Identity.syncIdentifier(identifierType: "guid", identifier: "12345", authenticationState: .loggedOut)
//        Identity.syncIdentifier(identifierType: "hhid", identifier: "67890", authenticationState: .loggedOut)
//        Identity.syncIdentifier(identifierType: "secretid", identifier: "1234567890", authenticationState: .loggedOut)
        
        userMembershipLevel = ""
    }
    
}

// MARK:  Getting Target Identifiers

extension AEPSDKManager {

    /**
     Start collecting Customer ID (GUID), ECID, tntId, sessionId in the same order or read them from cache
     */
    static func collectAEPIdentifiers(completion: @escaping ([String: String]) -> Void) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Dictionary to store the results
        var resultDict = [String: String]()
        
        // Dispatch group to wait for both async operations to complete
        let dispatchGroup = DispatchGroup()

        // First async call
        dispatchGroup.enter()
        Edge.getLocationHint { (hint, error) in
            if let error = error {
                print("Error retrieving location hint: \(error)")
                dispatchGroup.leave()
            } else if let hint = hint {
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                resultDict["locationHint"] = hint
                print("Retrieved location hint \(hint) in \(timeElapsed) seconds")
                dispatchGroup.leave()
            }
        }

        // Second async call
        dispatchGroup.enter()
        Identity.getExperienceCloudId { (ecid, error) in
            if let error = error {
                print("Error retrieving ECID: \(error)")
                dispatchGroup.leave()
            } else if let ecid = ecid {
                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
                resultDict["ecid"] = ecid
                print("Retrieved ECID \(ecid) in \(timeElapsed) seconds")
                dispatchGroup.leave()
            }
        }

        // Notify when both calls have finished
        dispatchGroup.notify(queue: .main) {
            // Call the completion handler with the result dictionary
            completion(resultDict)
        }
    }
   
    
    /// Gets well-formatted Adobe URL parameters required for seamless web view integration with native code
    static func getUrlVariablesForWebview(completion: @escaping (String?) -> Void){
        
        let previewParamKeys = ["at_preview_listed_activities_only", //ex: "true"
                             "at_preview_token", //ex: "mhFIzJSF7JWb-RsnakpBqlvOU5dAZxljCIJxLpNdtiw"
                             "at_preview_index"] // ex: "7356277"
        var previewParams = ""
        previewParamKeys.forEach { paramKey in
            if let val = AEPSDKManager.appEntryUrlParameters[paramKey]{
                previewParams += "&paramKey="+val
            }
        }
        // but we will use similar method Identity.getUrlVariables
        Identity.getUrlVariables { (urlVariables, error) in
            if error == nil {
                Edge.getLocationHint { (hint, error) in
                  if let error = error {
                      print("Location hint error: \(error)")
                  } else {
                      completion(
                          (urlVariables ?? "") +
                          previewParams +
                          "&location_hint=" + (hint ?? "")
                      )
                  }
                }
            }else{
                completion(previewParams)
            }
        }
    }
    
    static func printAllUserDefaults() {
        let userDefaults = UserDefaults.standard
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            print("UserDefaults \(key) = \(value) \n")
        }
    }
    
    
  
    static func experimentWithIdentifiers (){
        //let identityMap = IdentityMap()
        //identityMap.add(item: IdentityItem(id: FPID), withNamespace: "FPID")
        //Identity.updateIdentities(with: identityMap)

        do {
            let jsonData = try readJSONFile(from: "com.adobe.aep.datastore", with: "com.adobe.module.identity.json")
            print("||==>> JSON Data: \(jsonData)")
        } catch {
            print("Error reading JSON file: \(error)")
        }
        
//            getSeededEcidFromFpid(fpid: "a2aa476c-fa28-409f-83f4-51f397d99562") { (result, error) in
//                if let newEcid = result {
//                    print("||==>> ECID from FPID is success: \(result)")
//
//                    do {
//                        try updateEcidInJSONFile(from: "com.adobe.aep.datastore", with: "com.adobe.module.identity.json", newEcid: newEcid)
//                        print("||==>> ECID value updated successfully to \(newEcid).")
//                    } catch {
//                        print("||==>> Error updating ECID value: \(error)")
//                    }
//
//                } else if let error = error {
//                    print("ECID from FPID error: \(error.localizedDescription)")
//                }
//            }
    }
    
    /// Populates the fields with values stored in the Identity data store
//    mutating func loadFromPersistence() {
//        let dataStore = NamedCollectionDataStore(name: "com.adobe.module.identity")
//        let savedProperties: IdentityProperties? = dataStore.getObject(key: "identity.properties")
//
//    }
    
    static func listAllFilesInDocumentsDirectory() {
        
        let fm = FileManager.default
        let path = "com.adobe.aep.datastore" //Bundle.main.resourcePath

        do {
            let items = try fm.contentsOfDirectory(atPath: path)

            for item in items {
                print("===>> Found \(item)")
            }
        } catch {
            // failed to read directory – bad permissions, perhaps?
        }
        
        
        print("===>> fileURL in listAllFilesInDocumentsDirectory")
        let adobeDirectory = "com.adobe.aep.datastore"
        let fileManager = FileManager.default
        
        // Get the path to the documents directory
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not find the documents directory.")
            return
        }
        
        do {
            // Get the list of all files in the documents directory
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [])
            
            // Print the list of file URLs
            for fileURL in fileURLs {
                print("===>> fileURL \(fileURL.path)")
            }
        } catch {
            print("Error while enumerating files in documents directory: \(error.localizedDescription)")
        }
    }
    
    /// Reads the contents of a JSON file from the Library directory.
    ///
    /// - Parameters:
    ///   - subdirectory: The subdirectory under the Library directory.
    ///   - fileName: The name of the JSON file.
    /// - Returns: The contents of the JSON file as a dictionary.
    /// - Throws: An error if the file cannot be read or the JSON is invalid.
    static func readJSONFile(from subdirectory: String, with fileName: String) throws -> [String: Any] {
        // Get the path to the Library directory
        let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        
        // Construct the full path to the JSON file
        let fileURL = libraryDirectory.appendingPathComponent(subdirectory).appendingPathComponent(fileName)
        
        // Read data from the file
        let data = try Data(contentsOf: fileURL)
        
        // Parse the JSON data
        if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            return jsonObject
        } else {
            throw NSError(domain: "FileReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        
    }
    
    /// Reads the contents of a JSON file from the Library directory, updates the "ecid" value, and writes it back.
        ///
        /// - Parameters:
        ///   - subdirectory: The subdirectory under the Library directory.
        ///   - fileName: The name of the JSON file.
        ///   - newEcid: The new ECID string to update in the JSON file.
        /// - Throws: An error if the file cannot be read, the JSON is invalid, or the file cannot be written.
        static func updateEcidInJSONFile(from subdirectory: String, with fileName: String, newEcid: String) throws {
            // Get the path to the Library directory
            let libraryDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            
            // Construct the full path to the JSON file
            let fileURL = libraryDirectory.appendingPathComponent(subdirectory).appendingPathComponent(fileName)
            
            // Read data from the file
            let data = try Data(contentsOf: fileURL)
            
            // Parse the JSON data using SwiftyJSON
            var json = try JSON(data: data)
            print("||==>> JSON data parsed successfully: \(json)")
            
            // Decode the nested JSON string within "identity.properties"
            if let identityPropertiesString = json["identity.properties"].string,
               let identityPropertiesData = identityPropertiesString.data(using: .utf8) {
                var identityPropertiesJson = try JSON(data: identityPropertiesData)
                
                // Navigate to the "ecidString" key and update its value
                identityPropertiesJson["ecid"]["ecidString"].string = newEcid
                
                // Convert the updated identityPropertiesJson back to a string
                if let updatedIdentityPropertiesData = try? identityPropertiesJson.rawData(),
                   let updatedIdentityPropertiesString = String(data: updatedIdentityPropertiesData, encoding: .utf8) {
                    json["identity.properties"].string = updatedIdentityPropertiesString
                }
            } else {
                throw NSError(domain: "FileUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid identity.properties key"])
            }
            
            print("||==>> Updated JSON data: \(json)")
            
            // Convert the updated JSON object back to Data
            let updatedData = try json.rawData(options: .prettyPrinted)
            
//            // Parse the JSON data
//            guard var jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
//            else {
//                throw NSError(domain: "FileUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "||==>> Invalid JSON format or missing keys"])
//            }
//            
//            print("||==>> Loaded JSON \(jsonObject)")
//            
//            guard var identityProperties = jsonObject["identity.properties"] as? [String: Any]
//            else {
//                throw NSError(domain: "FileUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "||==>> Missing identity.properties key"])
//            }
//            
//            print("||==>> Loaded identityProperties \(identityProperties)")
//            
//            guard var ecidDict = identityProperties["ecid"] as? [String: Any]
//            else {
//                throw NSError(domain: "FileUpdater", code: 1, userInfo: [NSLocalizedDescriptionKey: "||==>> Missing ecid keys"])
//            }
//            
//            // Update the ECID value
//            ecidDict["ecidString"] = newEcid
//            identityProperties["ecid"] = ecidDict
//            jsonObject["identity.properties"] = identityProperties
//            
//            print("||==>> identityProperties \(identityProperties)")
//            
//            // Convert the updated JSON object back to Data
//            let updatedData = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
            
            // Write the updated data back to the file
            try updatedData.write(to: fileURL, options: .atomic)
        }
    
    /**
    * This is an experiment method and should NOT be used.
    * Make POST request to Edge Server API with FPID only to get seeded ECID
    */
    static func getSeededEcidFromFpid(fpid: String, completion: @escaping (String?, Error?) -> Void) {

        let urlString = "https://experienceedgeearlyaccess.data.adobedc.net/ee/v1/interact?configId=c4131c85-83c9-4e3d-9411-c7aa52e38fd2&requestId=E065A161-F129-4FDB-A93F-7405D47E35CB"
        
        let parameters: [String: Any] = [
            "query": [
                "identity": [
                    "fetch": [
                        "ECID"
                    ]
                ]
            ],
            "xdm": [
                "identityMap": [
                    "FPID": [
                        [
                            "id": fpid,
                            "authenticatedState": "ambiguous",
                            "primary": false
                        ]
                    ]
                ],
                "implementationDetails": [
                    "version": "4.2.0+4.3.0",
                    "name": "https://ns.adobe.com/experience/mobilesdk/ios",
                    "environment": "app"
                ]
            ],
            "events": [
                [
                    "xdm": [
                        "foo": "bar2foo",
                        "_id": "6900BB25-3A15-449C-A4D3-EE04F4153D24",
                        "timestamp": "2024-05-24T19:29:28.707Z",
                        "eventType": "personalization.request"
                    ]
                ]
            ]
        ]
        
        guard let url = URL(string: urlString) else {
           completion(nil, NSError(domain: "invalidURLError", code: -100002, userInfo: nil))
           return
       }

        var request = URLRequest(url: url, timeoutInterval: Double.infinity)

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("===>> Request: url \(urlString) body \(jsonString)")
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpMethod = "POST"
            request.httpBody = jsonData
            
        } catch let error {
            completion(nil, error)
            return
        }

        let task: URLSessionDataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            
            guard let data = data else {
                print("===>> Response Error: \(String(describing: error))")
                completion(nil, error)
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let swiftyJson = try? JSON(data: data)
                
                
                if let ecid = swiftyJson?[0]["handle"][0]["payload"][0]["id"].string {
                    print("===>> Parsed ecid: \(ecid)")
                } else {
                    print("===>> ECID not found or JSON structure is incorrect")
                }
                
                // Safely access the nested value using SwiftyJSON
                if let handleArray = swiftyJson?["handle"].array {
                    for handle in handleArray {
                        if let payloadArray = handle["payload"].array {
                            for payload in payloadArray {
                                if let ecid = payload["id"].string {
                                    print("===>> Parsed ecid 2: \(ecid)")
                                    completion(ecid, nil)
                                    return
                                }
                            }
                        }
                    }
                } else {
                    print("ECID not found or JSON structure is incorrect")
                }
                
                //print("===>> Response JSON: \(String(describing: json))")
                completion(nil, nil)
            } catch let error {
                print("===>> JSON Parsing Error: \(error.localizedDescription)")
                completion(nil, error)
            }
            
        }
        
        task.resume()
    }
    
    
}



/**
 WKWebView extension extends Adobe Identifiers syncing between native and web views
 Author: Adobe Consulting, ustymenk@adobe.com
 */
extension WKWebView {
    /**
     Passes ECID (marketingCloudId), tntId and sessionId
     from the Native app into the Web View in order to sync visitors in the hybrid app
     Requirements: must be executed before webView.load method in order to execute Adobe related JavaScript for cookie saving
     Example:
        self.webView.syncAdobeIdentifiersBeforeWebViewLoad(webview: self.webView)
        self.webView.load(request as URLRequest)
     */
    func syncAdobeIdentifiersBeforeWebViewLoad (webview: WKWebView) {
        /// JavaScript that defined functions for cookie saving and expiration
        var jsCode = "function setAdobeCookie(cname,cvalue,exdays){const d=new Date();d.setTime(d.getTime()+(exdays*24*60*60*1000));let expires='expires='+ d.toUTCString();document.cookie=cname+'='+cvalue+';'/* +expires+';path=/'; */ };function getAdobeExpiry(addSec){return parseInt((new Date().getTime()/1000).toFixed(0))+addSec};"
        /// Try reading ECID from app's cache and wrap around JS code to save to "s_ecid" cookies
        if let ecid = UserDefaults.standard.string(forKey: "Adobe.visitorIDServiceDataStore.ADOBEMOBILE_PERSISTED_MID") {
            let ecidCookie = "setAdobeCookie('s_ecid','MCMID|\(ecid)',(365*2));"
            jsCode = jsCode + ecidCookie
        }
        /// Try reading sessionId and tntId from app's cache and wrap around JS code to save to "mbox" cookies
        if let sessionId = UserDefaults.standard.string(forKey: "Adobe.ADOBEMOBILE_TARGET.SESSION_ID"),
           let tntId = UserDefaults.standard.string(forKey: "Adobe.ADOBEMOBILE_TARGET.TNT_ID"),
           sessionId.count > 0, tntId.count > 0{
            let mboxCookie = "setAdobeCookie('mbox','session#\(sessionId)#'+getAdobeExpiry(60*30)+'|PC#\(tntId)#'+getAdobeExpiry(60*60*24*365),(365*2));"
            jsCode = jsCode + mboxCookie
        }
        print("JS code to be executed in the web view: \(jsCode)")
        /// Inject code before Document start to save all cookies into the web view
        let cookieScript = WKUserScript(source: jsCode,
                                            injectionTime: .atDocumentStart,
                                            forMainFrameOnly: false)
        /// Execute script within configuration
        webview.configuration.userContentController.addUserScript(cookieScript)
    }
}
