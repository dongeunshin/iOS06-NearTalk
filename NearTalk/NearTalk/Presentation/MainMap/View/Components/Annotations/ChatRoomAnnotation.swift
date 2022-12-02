//
//  ChatRoomAnnotation.swift
//  NearTalk
//
//  Created by lymchgmk on 2022/11/15.
//

import MapKit

final class ChatRoomAnnotation: NSObject, Decodable, MKAnnotation {
    enum RoomType: Int, Decodable, CaseIterable {
        case group
        case directMessage
    }
    
    let chatRoomInfo: ChatRoom
    let roomType: RoomType
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    @objc
    dynamic var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(chatRoomInfo: ChatRoom, roomType: RoomType, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        self.chatRoomInfo = chatRoomInfo
        self.roomType = roomType
        self.latitude = latitude
        self.longitude = longitude
    }
    
    static func create(with chatRoomInfo: ChatRoom) -> ChatRoomAnnotation? {
        guard let roomType: ChatRoomAnnotation.RoomType = chatRoomInfo.roomType == "group" ? .group : .directMessage,
              let latitude = chatRoomInfo.location?.latitude,
              let longitude = chatRoomInfo.location?.longitude else { return nil }
        
        return ChatRoomAnnotation(chatRoomInfo: chatRoomInfo,
                                  roomType: roomType,
                                  latitude: latitude,
                                  longitude: longitude)
    }
}
