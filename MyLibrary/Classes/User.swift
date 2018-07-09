//
//  User.swift
//  Hrp_iOS
//
//  Created by Mohamed AITBELARBI on 20/06/2018.
//  Copyright © 2018 IMPRIMERIE NATIONALE. All rights reserved.
//

import Foundation
import ObjectMapper

private class User: Mappable {
    var id: String?
    var userId: String?
    var pushToken: String?
    var voiceIt: String?
    var userName: String?
    var gUId: String?
    var secret: String?
    var accountReference: String?
    var lastName: String?
    var firstName: String?
    
    required init?(map: Map){
        
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        userId <- map["user_id"]
        pushToken <- map["push_token"]
        voiceIt <- map["voice_it"]
        userName <- map["username"]
        gUId <- map["g_uid"]
        secret <- map["secret"]
        accountReference <- map["challenge_id"]
        lastName <- map["lastname"]
        firstName <- map["firstname"]
    }
}
