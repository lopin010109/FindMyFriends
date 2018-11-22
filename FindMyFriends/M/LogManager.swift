//
//  LogManager.swift
//  FindMyFriends
//
//  Created by Josh Hsieh on 2018/11/6.
//  Copyright © 2018 Josh. All rights reserved.
//

import Foundation
import SQLite

struct FriendsInfo: Codable {
    var id: String
    var friendName: String
    var lat: String
    var lon: String
    var lastUpdateDateTime: String
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case friendName = "friendName"
        case lat = "lat"
        case lon = "lon"
        case lastUpdateDateTime = "lastUpdateDateTime"
    }
    
}


class LogManager {
    static let tableName = "Location"
    static let midKey = "mid"
    static let idKey = "id"
    static let friendNameKey = "friendName"
    static let latKey = "lat"
    static let lonKey = "lon"
    static let lastUpdateDateTimeKey = "lastUpdateDateTime"
    
    // SQlite.swift support.
    var db:  Connection!
    var logTable = Table(tableName)
    var midColumn = Expression<Int64>(midKey)
    var idColumn = Expression<String>(idKey)
    var friendNameColumn = Expression<String>(friendNameKey)
    var latColumn = Expression<String>(latKey)
    var lonColumn = Expression<String>(lonKey)
    var lastUpdateDateTimeColumn = Expression<String>(lastUpdateDateTimeKey)
    
    var friendsInfoIDs = [Int64]()
    
    init() {
        // Prepare DB filename/path.
        let filemanager = FileManager.default
        let documentsURL = filemanager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURLPath = documentsURL.appendingPathComponent("log.sqlite").path
        var isNewDB = false
        if !filemanager.fileExists(atPath: fullURLPath) {
            isNewDB = true
        }
        
        do {
            db = try Connection(fullURLPath)
        } catch {
            assertionFailure("Fail to create connection.")
            return
        }
        
        // Create Table at the first time. 建立資料庫
        if isNewDB {
            do {
                let command = logTable.create { (builder) in
                    builder.column(midColumn, primaryKey: true)
                    builder.column(idColumn)
                    builder.column(friendNameColumn)
                    builder.column(latColumn)
                    builder.column(lonColumn)
                    builder.column(lastUpdateDateTimeColumn)
                }
                try db.run(command)
                print("Debug 1 >>> \(command)")
                print("Log table is created OK.")
            } catch {
                assertionFailure("Fail to create table: \(error)")
            }
        } else {
            // keep mid into messageIDs.
            do {
                // SELECT * FROM "messageLog"
                for friendsInfo in try db.prepare(logTable) {
                    friendsInfoIDs.append(friendsInfo[midColumn])
                }
            } catch {
                assertionFailure("Fail to execute prepare command: \(error)")
            }
            print("There are total \(friendsInfoIDs.count) messages in MyFriends DB.")
        }
    }
    
    var count: Int {
        return friendsInfoIDs.count
    }
    
    // 新增
    func append(_ friendsInfo: FriendsInfo) {
        
        let command = logTable.insert(idColumn <- friendsInfo.id,
                                      friendNameColumn <- friendsInfo.friendName,
                                      latColumn <- friendsInfo.lat,
                                      lonColumn <- friendsInfo.lon,
                                      lastUpdateDateTimeColumn <- friendsInfo.lastUpdateDateTime)
        print("Debug 2 >>> \(command)")
        do {
            let newFriendsInfoID = try db.run(command)
            friendsInfoIDs.append(newFriendsInfoID)
        } catch {
            assertionFailure("Fail to insert a new message: \(error)")
        }
    }
    
    // 讀取
    func getFreindsInfo(at: Int) -> FriendsInfo? {
        guard at >= 0 && at < count else {
            assertionFailure("Invalid message index.")
            return nil
        }
        let targetFriendsInfoID = friendsInfoIDs[at]
        // SELECT * FROM "lonMessage" WHERE mid == xxxx;
        let results = logTable.filter(midColumn == targetFriendsInfoID)
        // Pick the first one.
        do {
            guard let friendInfo = try db.pluck(results) else {
                assertionFailure("Faile to get the only one result.")
                return nil
            }
            return FriendsInfo(id: friendInfo[idColumn], friendName: friendInfo[friendNameColumn], lat: friendInfo[latColumn], lon: friendInfo[lonColumn], lastUpdateDateTime: friendInfo[lastUpdateDateTimeColumn])
        } catch {
            print("Pluck fail: \(error)")
        }
        return nil
    }
    
}

struct MyLocation: Codable {
    var lat: Double
    var lon: Double
    
    enum CodingKeys: String, CodingKey {
        case lat = "lat"
        case lon = "lon"
    }
}

class LogMyLocation {
    static let tableName = "Location"
    static let midKey = "mid"
    static let latKey = "lat"
    static let lonKey = "lon"
    
    var db: Connection!
    var logTable = Table(tableName)
    var midColumn = Expression<Int64>(midKey)
    var latColumn = Expression<Double>(latKey)
    var lonColumn = Expression<Double>(lonKey)
    
    var myLocationIDs = [Int64]()
    
    init() {
        // Prepare DB filename/path.
        let filemanager = FileManager.default
        let documentsURL = filemanager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURLPath = documentsURL.appendingPathComponent("log01.sqlite").path
        var isNewDB = false
        if !filemanager.fileExists(atPath: fullURLPath) {
            isNewDB = true
        }
        
        do {
            db = try Connection(fullURLPath)
        } catch {
            assertionFailure("Fail to create connection.")
            return
        }
        
        // Create Table at the first time. 建立資料庫
        if isNewDB {
            do {
                let command = logTable.create { (builder) in
                    builder.column(midColumn, primaryKey: true)
                    builder.column(latColumn)
                    builder.column(lonColumn)
                }
                try db.run(command)
                print("Log table is created OK.")
                print("Debug 3 >>> \(command)")
            } catch {
                assertionFailure("Fail to create table: \(error)")
            }
        } else {
            // keep mid into messageIDs.
            do {
                // SELECT * FROM "messageLog"
                for myLocation in try db.prepare(logTable) {
                    myLocationIDs.append(myLocation[midColumn])
                }
            } catch {
                assertionFailure("Fail to execute prepare command: \(error)")
            }
            print("There are total \(myLocationIDs.count) messages in MyLocation DB.")
        }
    }
    
    var count: Int {
        return myLocationIDs.count
    }
    
    // 新增
    func append(_ myLocation: MyLocation) {
        
        let command = logTable.insert(latColumn <- Double(myLocation.lat),
                                      lonColumn <- Double(myLocation.lon))
        do {
            let newMyLocationID = try db.run(command)
            myLocationIDs.append(newMyLocationID)
            print("Debug append >>> \(newMyLocationID)")
        } catch {
            assertionFailure("Fail to inser a new message: \(error)")
        }
    }
    
    // 讀取
    func getMyLocation(at: Int) -> MyLocation? {
        guard at >= 0 && at < count else {
            assertionFailure("Invalid message index.")
            return nil
        }
        let targetMyLocation = myLocationIDs[at]
        // SELECT * FROM "lonMessage" WHERE mid == xxxx;
        let results = logTable.filter(midColumn == targetMyLocation)
        // Pick the first one.
        do {
            guard let myLocation = try db.pluck(results) else {
                assertionFailure("Faile to get the only one result.")
                return nil
            }
            return MyLocation(lat: (myLocation[latColumn]), lon: myLocation[lonColumn])
        } catch {
            print("Pluck fail: \(error)")
        }
        return nil
    }
    
}
