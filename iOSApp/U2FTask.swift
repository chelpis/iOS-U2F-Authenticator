//
//  U2FParser.swift
//  iOSApp
//
//  Created by dannynash on 2018/6/15.
//  Copyright © 2018 GitHub. All rights reserved.
//

import Foundation
import ObjectMapper


let GenerateRegistrationResponseMessage = "generate_registration_response_message"
let GenerateKeyHandleCheckingResponse = "generate_key_handle_checking_response"
let GenerateAuthenticationResponseMessage = "generate_authentication_response_message"

class U2FTask: NSObject, Mappable {
    var funcName: String = ""
    var args = [String]()
    required convenience init?(map: Map) {
        self.init()
    }

    func mapping(map: Map) {
        funcName    <- map["funcName"]
        args    <- map["args"]
    }
}

class U2FResponse: NSObject, Mappable {
    var sw = ""
    var resp = ""
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    func mapping(map: Map) {
        sw    <- map["sw"]
        resp    <- map["resp"]
    }
}
