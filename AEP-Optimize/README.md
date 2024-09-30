#  AEP Optimize SDK Demo App

> This demo app demonstrates best practices implementating Adobe Target with AEP Optimize SDK. 


## AEP SDK Implementation Overview:

1. Importing and registering extensions (see `AppDelegate`)
2. TODO: Deep linking for visual preview (see `application(_:open:options:)` in `AppDelegate`)
3. SDK methods and custom convenience methods (see `AEPSDKManager`)
4. Displaying personalized content (see `ViewController`, `ProductTableViewController`, `LoginViewController`)
5. TODO: Embedding web views from native code and passing Adobe identifiers (see `OrderViewController`) 


## Prefetching and Displaying Personalization

Optimize SDK offers 3 key methods for loading personalized content: `updatePropositions` is to prefetch supplied decision scopes and `getPropositions` is to get content for supplied decision scopes. When content is displayed, `Offer.displayed` method triggers notificaiton call to AEP to notify the content was seen.

### Prefetching 

To prefetch personalization from AEP edge into the mobile app's memory, we can use `updatePropositions` method in Optimize SDK. Personalized experiences can be prefetched in the following major app entry points:

   - Initial app load (see `AppDelegate.application(_:didFinishLaunchingWithOptions:)`)
   - App re-entry (see `AppDelegate.applicationWillEnterForeground(_:)`)
   - User authentication
   - User purchase completion
   
```
    Optimize.updatePropositions(for: decisionScopesToPrefetch, withXdm: xdmData)
```
   
> Note: we can prefetch content as many times as needed during the user journey in the app

> Migration note: `Optimize.updatePropositions` replaces `Target.prefetchContent`

### Pre-hiding 

Pre-hiding app content that we test on app entry positively affects user experience. While personalization call is in action, temporarily hiding content allows to not expose default content. Good practice includes:

  - Prehide content (see `ViewController.viewWillAppear`)
  - Make a call to AEP and then apply personalized content
  - Unhide content
     
### Displaying

To display personalized content that was prefetched, we can use `getPropositions` method in Optimize SDK. It is important to execute `updatePropositions` first before `getPropositions` method. There are internal queues to ensure propositions will return if call is still pending.

```
    Optimize.getPropositions(for: decisionScopes) { propositionsDict, error in
        //...
    })
```

> Migration note: `Optimize.getPropositions` replaces `Target.retrieveLocationContent`

### Notifying

Lastly, after getting content from `getPropositions` we will send a notification to the edge to esnure the visit counts. This also automatically forwards the call to A4T on the Adobe network, if Target activity reports to Analytics  

```
    Offer.displayed()
```

> Migration note: `Offer.displayed` replaces `Target.displayedLocations`



## Syncing Native Code with Web Views

Appending ECID with `Identity.append` or `Identity.getUrlVariables` (see `OrderViewController`)

```
    Identity.getUrlVariables { (urlVariables, error) in
        // eg URL variables adobe_mc=TS%3D1724346272%7CMCMID%3D88229830178179816824858083869067640341%7CMCORGID%3DEB9CAE8B56E003697F000101%40AdobeOrg&location_hint=va6
    }
```

Additionally, you can pass a **Location Hint** (Edge Cluster) to connect to the same edge

```
    Edge.getLocationHint { (hint, error) in /.../ }
```

## ID Synchronization for Visitor Identification

Sending one or multiple customer IDs to Adobe for identification:
`ACPIdentity.syncIdentifiers(identifiers, authentication: .authenticated)` 
    - See `LoginViewController.didTapLogin`
    - Fetch Target offers again if necessary to re-qualify to different activities after login




## Target Order Confirmation Location

1. TODO: Sending order confirmation Location to Target


## Places Extension

- POIs entered in Places Service (https://experience.adobe.com/#/@ags300/places)
- Launch rule set (see  https://docs.adobe.com/content/help/en/places/using/use-places-with-other-solutions/places-target/places-target.html)
- Target activity created (see section "Loading Target Activities")


## In-App Messaging

- TODO Send a real time notification when someone enters a POI, "Hey..welcome to the stadium."



## Analytics Extension

- TODO
