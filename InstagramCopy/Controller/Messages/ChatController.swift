//
//  ChatController.swift
//  InstagramCopy
//
//  Created by Stephan Dowless on 3/28/18.
//  Copyright © 2018 Stephan Dowless. All rights reserved.
//

import UIKit
import Firebase

private let reuseIdentifier = "ChatCell"

class ChatController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    // MARK: - Properties
    
    var user: User?
    var messages = [Message]()
    
    lazy var containerView: MessageInputAccesoryView = {
        let frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 50)
        let containerView = MessageInputAccesoryView(frame: frame)
        containerView.delegate = self
        return containerView
    }()
    
    // MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView?.backgroundColor = .white
        collectionView?.register(ChatCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        configureNavigationBar()
        
        observeMessages()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
    }
    
    override var inputAccessoryView: UIView? {
        get {
            return containerView
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    // MARK: - UICollectionView
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        
        if let messageText = message.messageText {
            height = estimateFrameForText(messageText).height + 20
        } else if let imageWidth = message.imageWidth?.floatValue, let imageHeight = message.imageHeight?.floatValue {
            height = CGFloat(imageHeight / imageWidth * 200)
        }
        
        return CGSize(width: view.frame.width, height: height)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! ChatCell
        
        cell.message = messages[indexPath.item]
        
        configureMessage(cell: cell, message: messages[indexPath.item])
        
        return cell
    }
    
    // MARK: - Handlers
    
    @objc func handleInfoTapped() {
        let userProfileController = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileController.user = user
        navigationController?.pushViewController(userProfileController, animated: true)
    }

    
    func estimateFrameForText(_ text: String) -> CGRect {
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 16)], context: nil)
    }
    
    func configureMessage(cell: ChatCell, message: Message) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        if let messageText = message.messageText {
            cell.bubbleWidthAnchor?.constant = estimateFrameForText(messageText).width + 32
            cell.frame.size.height = estimateFrameForText(messageText).height + 20
        } else if message.imageUrl != nil {
            cell.bubbleWidthAnchor?.constant = 200
        }
        
        if let messageImageUrl = message.imageUrl {
            cell.messageImageView.loadImage(with: messageImageUrl)
            cell.messageImageView.isHidden = false
            cell.bubbleView.backgroundColor = .clear
        } else {
            cell.messageImageView.isHidden = true
            cell.bubbleView.backgroundColor  = UIColor.rgb(red: 0, green: 137, blue: 249)
        }
        
        if message.fromId == currentUid {
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
            cell.bubbleView.backgroundColor = UIColor.rgb(red: 0, green: 137, blue: 249)
            cell.textView.textColor = .white
            cell.profileImageView.isHidden = true
        } else {
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
            cell.bubbleView.backgroundColor = UIColor.rgb(red: 240, green: 240, blue: 240)
            cell.textView.textColor = .black
            cell.profileImageView.isHidden = false
        }
    }
    
    func configureNavigationBar() {
        guard let user = self.user else { return }
        
        navigationItem.title = user.username
        
        let infoButton = UIButton(type: .infoLight)
        infoButton.tintColor = .black
        infoButton.addTarget(self, action: #selector(handleInfoTapped), for: .touchUpInside)
        let infoBarButtonItem = UIBarButtonItem(customView: infoButton)
        
        navigationItem.rightBarButtonItem = infoBarButtonItem
    }
    
    // MARK: - API
    
    func uploadMessageToServer(withImageUrl imageUrl: String? = nil, image: UIImage? = nil, message: String? = nil) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let user = self.user else { return }
        let creationDate = Int(NSDate().timeIntervalSince1970)
    
        var isImageMessage: Bool!
        var messageValues: [String: Any]!
        
        if let imageUrl = imageUrl {
            isImageMessage = true
            messageValues = ["creationDate": creationDate, "fromId": currentUid,"toId": user.uid,
                             "imageUrl": imageUrl, "imageWidth": image?.size.width as Any, "imageHeight": image?.size.height as Any] as [String: Any]
        } else {
            isImageMessage = false
            guard let message = message else { return }
            messageValues = ["creationDate": creationDate,"fromId": currentUid, "toId": user.uid,
                             "messageText": message] as [String: Any]
        }
        
        let messageRef = MESSAGES_REF.childByAutoId()
        messageRef.updateChildValues(messageValues)
        
        USER_MESSAGES_REF.child(currentUid).child(user.uid).updateChildValues([messageRef.key: 1])
        USER_MESSAGES_REF.child(user.uid).child(currentUid).updateChildValues([messageRef.key: 1])
        let message = Message(dictionary: messageValues as Dictionary<String, AnyObject>)
        uploadMessageNotification(forMessage: message, isImageMessage: isImageMessage)
    }
    
    func observeMessages() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let chatPartnerId = self.user?.uid else { return }
        
        USER_MESSAGES_REF.child(currentUid).child(chatPartnerId).observe(.childAdded) { (snapshot) in
            let messageId = snapshot.key
            self.fetchMessage(withMessageId: messageId)
        }
    }
    
    func fetchMessage(withMessageId messageId: String) {
        MESSAGES_REF.child(messageId).observeSingleEvent(of: .value) { (snapshot) in
            guard let dictionary = snapshot.value as? Dictionary<String, AnyObject> else { return }
            let message = Message(dictionary: dictionary)
            self.messages.append(message)
            self.collectionView?.reloadData()
        }
    }
    
    func uploadMessageNotification(forMessage message: Message, isImageMessage: Bool) {
        guard let fromId = Auth.auth().currentUser?.uid else { return }
        guard let toId = message.toId else { return }
        var messageText: String!
        
        if isImageMessage {
            messageText = "Sent an image"
        } else {
            messageText = message.messageText
        }
        
        let values = ["fromId": fromId,
                      "toId": toId,
                      "messageText": messageText] as [String : Any]
        
        USER_MESSAGE_NOTIFICATIONS_REF.child(toId).childByAutoId().updateChildValues(values)
    }
    
    func uploadImageToStorage(selectedImage image: UIImage) {
        let filename = NSUUID().uuidString
        guard let uploadData = UIImageJPEGRepresentation(image, 0.3) else { return }
        
        STORAGE_MESSAGE_IMAGES_REF.child(filename).putData(uploadData, metadata: nil) { (metadata, error) in
            if error != nil {
                print("DEBUG: Unable to upload image to Firebase Storage")
                return
            }
            
            guard let imageUrl = metadata?.downloadURL()?.absoluteString else { return }
            self.uploadMessageToServer(withImageUrl: imageUrl, image: image)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ChatController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let selectedImage = info[UIImagePickerControllerEditedImage] as? UIImage else { return }
        uploadImageToStorage(selectedImage: selectedImage)
        dismiss(animated: true, completion: nil)
    }
}

extension ChatController: MessageInputAccesoryViewDelegate {
    
    func handleUploadMessage(message: String) {
        uploadMessageToServer(withImageUrl: nil, image: nil, message: message)
        
        self.containerView.clearMessageTextView()
    }
    
    func handleSelectImage() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.allowsEditing = true
        present(imagePickerController, animated: true, completion: nil)
        
    }
}
