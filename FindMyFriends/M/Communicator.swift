//
//  Communicator.swift
//  FindMyFriends
//
//  Created by Josh Hsieh on 2018/10/30.
//  Copyright © 2018 Josh. All rights reserved.
//

import Foundation
import Alamofire


let GROUPNAME = "xxxxx"
let MY_NAME = "xxxxx"


// JSON Keys
let ID_KEY = "id"
let USERNAME_KEY = "UserName"
let GROUPNAME_KEY = "GroupName"
let LAT_KEY = "Lat"
let LON_KEY = "Lon"
let FRIENDNAME_KEY = "friendName"
let LASTUPDATEDATETIME_KEY = " lastUpdateDateTime"
let DATA_KEY = "data"
let RESULT_KEY = "result"


typealias DoneHandler = (_ result: [String: Any]?, _ error: Error?) -> Void

class Communicator {
    
    static let BASEURL = "http://xxxxx/xxxx/xxxxx/"
    let UPDATE_USERLOCATION_URL = BASEURL + "updateUserLocation.php?"
    let QUERY_FRIENDLOCATIONS_URL = BASEURL + "queryFriendLocations.php?"
    
    static let shared = Communicator()
    
    private init() {
        
    }
    

    func FreindsLocation(groupName: String, completion: @escaping DoneHandler) {
        
        
        let urlString = QUERY_FRIENDLOCATIONS_URL + "GroupName=\(groupName)"
        doPost(urlString: urlString, completion: completion)
    }
    
   
    
    func UserLocation(lat: String, lon: String, completion: @escaping DoneHandler) {
    
       
        let urlString = UPDATE_USERLOCATION_URL + "GroupName=\(GROUPNAME)&UserName=\(MY_NAME)&Lat=\(lat)&Lon=\(lon)"
        doPost(urlString: urlString, completion: completion)
    }
    
    
    
    private func doPost(urlString: String, completion: @escaping DoneHandler) {

        
        Alamofire.request(urlString, method: .post, encoding: URLEncoding.default).responseJSON { (response) in
            
            self.handleJSON(response: response, completion: completion)
            
        }
    }
    
    private func handleJSON(response: DataResponse<Any>, completion: DoneHandler) {
        
        switch response.result {
        case .success(let json):
            print("Get success response: \(json)")
            
            guard let finalJson = json as? [String: Any] else {
                let error = NSError(domain: "Invalid", code: -1, userInfo: nil)
                completion(nil, error)
                return
            }
            
            guard let result = finalJson[RESULT_KEY] as? Bool,
                result == true else {
                    let error = NSError(domain: "Server respond false or not result", code: -1, userInfo: nil)
                    completion(nil, error)
                    return
            }
            completion(finalJson, nil)
            
        case .failure(let error):
            print("Server respond error: \(error)")
            completion(nil, error)
        }
    }
}
