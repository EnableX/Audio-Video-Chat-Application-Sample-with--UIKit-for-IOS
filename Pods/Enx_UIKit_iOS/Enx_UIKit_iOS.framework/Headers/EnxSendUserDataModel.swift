//
//  EnxSendUserDataModel.swift
//  Enx_UIKit_iOS
//
//  Created by jaykumar on 17/08/23.
//

import UIKit

@objc
public class EnxSendUserDataModel: NSObject {
    var isBroadCase : Bool? = true
    var userData : [String : Any]! = [:]
    var clientList : [String]? = []
    
    public init(isBroadCase: Bool = true, userData: [String : Any]!, clientList: [String]? = nil) {
        self.isBroadCase = isBroadCase
        self.userData = userData
        self.clientList = clientList
    }
}
