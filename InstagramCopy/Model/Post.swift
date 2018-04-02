//
//  Post.swift
//  InstagramCopy
//
//  Created by Stephan Dowless on 2/9/18.
//  Copyright © 2018 Stephan Dowless. All rights reserved.
//

import Firebase
import Foundation

class Post {
    
    var caption: String!
    var likes: Int!
    var imageUrl: String!
    var ownerUid: String!
    var creationDate: Date!
    var postId: String!
    var user: User?
    var didLike = false
    
    init(postId: String!, user: User, dictionary: Dictionary<String, AnyObject>) {
        
        self.postId = postId
        
        self.user = user
        
        if let caption = dictionary["caption"] as? String {
            self.caption = caption
        }
        
        if let likes = dictionary["likes"] as? Int {
            self.likes = likes
        }
        
        if let imageUrl = dictionary["imageUrl"] as? String {
            self.imageUrl = imageUrl
        }
        
        if let ownerUid = dictionary["ownerUid"] as? String {
            self.ownerUid = ownerUid
        }
        
        if let creationDate = dictionary["creationDate"] as? Double {
            self.creationDate = Date(timeIntervalSince1970: creationDate)
        }
    }

    func adjustLikes(addLike: Bool, completion: @escaping(Int) -> ()) {
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        if addLike {
            
            // updates user-likes structure
            USER_LIKES_REF.child(currentUid).updateChildValues([postId: 1], withCompletionBlock: { (err, ref) in
                
                // send notification to server
                self.sendLikeNotificationToServer()
                
                // updates post-likes structure
                POST_LIKES_REF.child(self.postId).updateChildValues([currentUid: 1], withCompletionBlock: { (err, ref) in
                    self.likes = self.likes + 1
                    self.didLike = true
                    completion(self.likes)
                    POSTS_REF.child(self.postId).child("likes").setValue(self.likes)
                })
            })

        } else {
            
            // observe database for notification id to remove
            USER_LIKES_REF.child(currentUid).child(postId).observeSingleEvent(of: .value, with: { (snapshot) in
                
                // notification id to remove from server
                guard let notificationID = snapshot.value as? String else { return }
                
                // remove notification from server
                NOTIFICATIONS_REF.child(self.ownerUid).child(notificationID).removeValue(completionBlock: { (err, ref) in
                    
                    // remove like from user-like structure
                    USER_LIKES_REF.child(currentUid).child(self.postId).removeValue(completionBlock: { (err, ref) in
                        
                        // remove like from post-like structure
                        POST_LIKES_REF.child(self.postId).child(currentUid).removeValue(completionBlock: { (err, ref) in
                            guard self.likes > 0 else { return }
                            self.likes = self.likes - 1
                            self.didLike = false
                            completion(self.likes)
                            POSTS_REF.child(self.postId).child("likes").setValue(self.likes)
                        })
                    })
                    
                })
            })
        }
    }
    
    func sendLikeNotificationToServer() {
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        let creationDate = Int(NSDate().timeIntervalSince1970)
        
        if currentUid != self.ownerUid {
            
            // notification values
            let values = ["checked": 0,
                          "creationDate": creationDate,
                          "uid": currentUid,
                          "type": LIKE_INT_VALUE,
                          "postId": postId] as [String : Any]
            
            // notification database reference
            let notificationRef = NOTIFICATIONS_REF.child(self.ownerUid).childByAutoId()
            
            // upload notification values to database
            notificationRef.updateChildValues(values, withCompletionBlock: { (err, ref) in
                USER_LIKES_REF.child(currentUid).child(self.postId).setValue(notificationRef.key)
            })
        }
        
    }
}
