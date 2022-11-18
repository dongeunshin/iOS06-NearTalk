//
//  FirebaseKey.swift
//  NearTalk
//
//  Created by 고병학 on 2022/11/17.
//

import Foundation

enum FirebaseServiceType {

    enum FireStore: String {
        case users
        case chatRoom
    }
    
    enum RealtimeDB: String {
        case chatRooms
        case chatMessages
    }
    
    enum Storage: String {
        case images
        case videos
    }
}
