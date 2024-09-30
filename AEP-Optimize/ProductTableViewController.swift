//
//  ProductTableViewController.swift
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

class ProductTableViewController: UITableViewController {
    
    let productData = [
        // Section 1
        [   ["Product Header"],
            ["Product-AA", "Adobe Analytics", "subtitle", "#9F7FFF"],
             ["Product-AT", "Adobe Target", "subtitle", "#17D8FF"],
             ["Product-AC", "Adobe Campaign", "subtitle", "#D4F10D"],
             ["Product-AAM", "Adobe Audience Manager", "subtitle", "#6390FF"],
             ["Product-AEM", "Adobe Experience Manager", "subtitle", "#FF7618"],
            ["Product-AEP", "Adobe Experience Platform", "subtitle", "#F90025"]
        ]
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.tableView.register(UITableViewCell.self, forCellWithReuseIdentifier: "cell")

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print("in viewWillAppear")
        
        self.renderPrefetchedPropositions()
        
    }
     
    
    //MARK: table delegates
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        print("numberOfSections \(productData.count)")
        return productData.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70.0;
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("numberOfRowsInSection \(productData[0].count-1)")
        return productData[0].count-1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath)
        
        //let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "mycell")
        
        
        let cellData = productData[indexPath.section][indexPath.row + 1]
        // Configure the cell...
        
        print("cellData \(cellData[1]) \(cellData[2])")
        
        //cell.imageView?.image = UIImage(named: cellData[0])
        cell.imageView?.image = imageWithImage(image: UIImage(named: cellData[0])!, scaledToSize: CGSize(width: 50, height: 50))

        cell.imageView?.tintColor = UIColor(hexString: cellData[3] )
        cell.textLabel?.text = cellData[1]
        cell.detailTextLabel?.text = cellData[2]
        
        let buyNowLabel = UILabel()
        buyNowLabel.frame = CGRect(x: 0, y: 10, width: 80, height: 30)
        buyNowLabel.text = "Order >"
        buyNowLabel.textAlignment = .center
        buyNowLabel.layer.cornerRadius = 10
        buyNowLabel.layer.masksToBounds = true
        buyNowLabel.backgroundColor = UIColor(hexString: cellData[3])
        buyNowLabel.textColor = UIColor.white
        cell.accessoryView = buyNowLabel
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        self.performSegue(withIdentifier: "orderViewController", sender: self)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


// MARK: Target Implementation

extension ProductTableViewController{
    
    @objc func renderPrefetchedPropositions(){
        print("in ProductTableViewController.renderPrefetchedPropositions")
        
        
        MobileCore.registerEventListener(type: EventType.edge, source: EventSource.personalizationDecisions, listener: { event in
            
            print("MobileCore event for edge decisions: \(event)")
            
            // Change banner
            var decisionScopes = [DecisionScope]()
            for scope in ["sdk-demo-4","sdk-demo-6"]{
                decisionScopes.append(DecisionScope(name: scope))
            }
            Optimize.getPropositions(for: decisionScopes) { propositionsDict, error in
                print("prefetched content (sdk-demo-4) \(String(describing: propositionsDict))")
                if error == nil, let propositions = propositionsDict{
                    
                    // Update Home page image
                    if let message = AEPSDKManager.getValueFromPropositions(for: "promocode", decisionScope: "sdk-demo-4", propositions: propositions),
                       message.count > 0{
                        print("Target message \(message)")

                    }
                    
                    if let message = AEPSDKManager.getValueFromPropositions(for: "promocode", decisionScope: "sdk-demo-6", propositions: propositions),
                       message.count > 0{
                        print("Target message \(message)")
                    }
                }
            
            }
        })

    }
    
    func imageWithImage(image:UIImage,scaledToSize newSize:CGSize)->UIImage{

      UIGraphicsBeginImageContext( newSize )
        image.draw(in: CGRect(x: 0,y: 0,width: newSize.width,height: newSize.height))
      let newImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()
        return (newImage?.withRenderingMode(.alwaysTemplate))!
    }
    
    
}

extension UIColor {
    convenience init?(hexString: String, alpha: CGFloat = 1.0) {
        var formattedHex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        formattedHex = formattedHex.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: formattedHex).scanHexInt64(&rgb) else {
            return nil
        }
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
