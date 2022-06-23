//
//  EnxVideoViewClass.swift
//  Enx_UIKit_iOS
//
//  Created by Enx on 07/02/22.
//

import UIKit
import EnxRTCiOS

@objc
public protocol EnxVideoStateDelegate:AnyObject {
    func disconnect(response: [Any]?)
    func connectError(reason: [Any]?)
}

open class EnxVideoViewClass: UIView {
    //Private Object used inside this class
    private(set) var token : String!
    private(set)var loader : EnxLoaderView!
    private(set)var bottomView : EnxBottomOptionView!
    private(set) var enxrtc = EnxRtc()
    private(set) var localStream : EnxStream!
    private(set) var room: EnxRoom!
    private(set) var localPlayer : EnxPlayerView!
    private(set) var isSpeaker : Bool! = false
    private(set) var recordingImage : UIImageView!
    private(set) var topOption : EnxTopOptionView!
    weak var delegate: EnxVideoStateDelegate?
    private(set) var topViewHeight : CGFloat = 40.0
    private(set) var isOptionShow : Bool = true
    private(set) var enxparticipantView : EnxParticipantListView!
    private(set) var enxMenuView : EnxMenuView!
    private(set) var participantList : [EnxParticipantModelObject] = []
    private(set) var roomMode : String! = "group"
    private(set) var currentFloorStatus : String! = "noRequest"
    private(set) var enxReqPopOver : EnxrequestPopOverView!
    private(set) var moreOptionList : [EnxMenuOptionObject] = []
    private(set) var enxChatView : EnxChatViewListView!
    private var floorRequestList : [EnxRequestModel] = []
    private(set) var whichCharRoom : String = "non"
    private(set) var messageCount : Int = 0
    private(set) var enxAudioMediaView : EnxAudioMediaListView!
    
    @objc
    public init(token : String, delegate : EnxVideoStateDelegate?){
        self.token = token
        self.delegate = delegate 
        super.init(frame: .zero)
        setupView()
        
    }
   public required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    //Set-Up view
    func setupView() {
        self.backgroundColor = .clear
        loader = EnxLoaderView()
        self.addSubview(loader)
        loader.frame = self.bounds
        loader.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            createlocalPlayerView()
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceOrientationDidChange(_:)), name: NSNotification.Name(rawValue: UIDevice.orientationDidChangeNotification.rawValue), object: nil)
        guard let stream = enxrtc.joinRoom(token, delegate: self,
                                           publishStreamInfo: getLocalStreamInfo(isAudioMuted: false, isVideoMute: false, isAudioOnly: false),
                                           roomInfo: getRoomInfo(),
                                           advanceOptions: nil)
        else { return }
        localStream = stream
        localStream.delegate = self
        
        let tapGuseter = UITapGestureRecognizer(target: self, action: #selector(tapToShowAndHide))
        self.addGestureRecognizer(tapGuseter)
        tapGuseter.numberOfTapsRequired = 1
    }
    //Create local Publisher Stream
    func getLocalStreamInfo(isAudioMuted :Bool,isVideoMute : Bool, isAudioOnly :Bool ) -> [String : Any]{
        let videoSize: [String: Any] = ["minWidth": 320,
                                        "minHeight": 180,
                                        "maxWidth": 1280,
                                        "maxHeight": 720]
        let localStreamInfo: [String: Any] = ["video": true,
                                              "audio": true,
                                              "data": true,
                                              "audioMuted": isAudioMuted,
                                              "videoMuted": isVideoMute,
                                              "audio_only": isAudioOnly,
                                              "type": "public",
                                              "videoSize": videoSize,
                                              "maxVideoLayers": 1]
        return localStreamInfo
    }
    //Create Roominfo
    func getRoomInfo() ->[String : Any]{
        let playerConfiguration: [String: Any] = ["avatar": true,
                                                    "audiomute": true,
                                                    "videomute": true,
                                                    "bandwidht": true,
                                                    "screenshot": false,
                                                    "iconColor": "#dfc0ef"]
        
        let roomInfo: [String: Any] = ["allow_reconnect": true,
                                         "number_of_attempts": 3,
                                         "timeout_interval": 45,
                                         "chat_only": false,
                                         "forceTurn": false,
                                         "playerConfiguration": playerConfiguration,
                                         "activeviews": "view"]
        return roomInfo
    }
    func createlocalPlayerView(){
        let rect = self.bounds;
        localPlayer = EnxPlayerView(localView: CGRect(x: rect.width - 120, y: topViewHeight, width: 110, height: 130))
        self.addSubview(localPlayer)
        self.bringSubviewToFront(localPlayer)
        //localPlayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let localViewGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didChangePosition))
        localPlayer.addGestureRecognizer(localViewGestureRecognizer)
    }
    /**
        This method will change the position of localPlayerView
     Input parameter :- UIPanGestureRecognizer
     **/
   @objc func didChangePosition(sender: UIPanGestureRecognizer) {
        let location = sender.location(in: self)
        if sender.state == .began {
        } else if sender.state == .changed {
            if(location.x <= (self.bounds.width - (self.localPlayer.bounds.width/2)) && location.x >= self.localPlayer.bounds.width/2) {
                self.localPlayer.frame.origin.x = location.x
                localPlayer.center.x = location.x
            }
            if(location.y <= (self.bounds.height - (self.localPlayer.bounds.height + 40)) && location.y >= (self.localPlayer.bounds.height/2)+20){
                self.localPlayer.frame.origin.y = location.y
                localPlayer.center.y = location.y
            }
        } else if sender.state == .ended {
            print("Gesture ended")
        }
    }
    // Show and hide top/buttom option view
    @objc func tapToShowAndHide(sender : UITapGestureRecognizer){
        guard bottomView != nil && topOption != nil else{
            return
        }
        var viewAlpha = 0.0
        if(isOptionShow){
            viewAlpha = 0.0
        }
        else{
            viewAlpha = 1.0
        }
    
        UIView.animate(withDuration: 0.25, animations: { [self] in
            bottomView.alpha = viewAlpha
            topOption.alpha = viewAlpha
        }, completion: { [self]_ in
            if(isOptionShow){
                bottomView.isHidden = true
                topOption.isHidden = true
            }
            else{
                bottomView.isHidden = false
                topOption.isHidden = false
            }
            isOptionShow = !isOptionShow
        })
    }
    //Orientation Changes update
    @objc func deviceOrientationDidChange(_ notification: Notification){
        guard self.room != nil else{
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            self.room.adjustLayout()
        }
       
        updateLocalViewOrigin()
    }
    //Update Local View Origin
    private func updateLocalViewOrigin(){
        let rect = self.bounds;
        if(isOptionShow){
            topViewHeight = self.safeAreaLayoutGuide.layoutFrame.origin.y + topOption.bounds.height + 10
        }
        else{
            topViewHeight = self.safeAreaLayoutGuide.layoutFrame.origin.y + 5
        }
        localPlayer.frame = CGRect(x: rect.width - 120, y: topViewHeight, width: 110, height: 130)
    }
    private func addBottomOption(){
        bottomView = EnxBottomOptionView(optionList: EnxSetting.shared.getBottomOptionList(),colorComponent: EnxSetting.shared.getBottomOptionColor(), delegate: self)
        var rect = self.bounds;
        bottomView.rect = rect
        var maxWidth : CGFloat = 0.0
        let width : CGFloat  = CGFloat(60 * EnxSetting.shared.getBottomOptionList().count)
        if(rect.width > 410){
            maxWidth = 390;
        }
        else{
            maxWidth = rect.width - 20
        }
        if(width > maxWidth){
            rect.size.width = maxWidth
        }
        else{
            rect.size.width = width
        }
        rect.size.height = 50
        rect.origin.y = self.bounds.height - 65
        rect.origin.x = (self.bounds.width - rect.width)/2
        bottomView.frame = rect
        bottomView.backgroundColor = .white
        bottomView.layer.cornerRadius = 8.0
        self.addSubview(bottomView)
        self.bringSubviewToFront(bottomView)
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: 5.0).isActive = true
        bottomView.widthAnchor.constraint(equalToConstant: bottomView.bounds.width).isActive = true
        bottomView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        bottomView.heightAnchor.constraint(equalToConstant: bottomView.bounds.height).isActive = true
    }
    
    func getUserRole() -> Bool{
        guard self.room != nil else { return false }
        var isModeartor : Bool = false
        if self.room.userRole == "moderator" {
            isModeartor = true
        }
        return isModeartor
    }
    //UI for recording Session
    private func recordingUi(_ isStarted : Bool){
        if(isStarted){
            if let bundle = EnxSetting.shared.getPath(){
                let animitedImage : [UIImage]?  = [UIImage(contentsOfFile: bundle.path(forResource: "ani-recording", ofType: "png")!)!,UIImage(contentsOfFile: bundle.path(forResource: "animated", ofType: "png")!)!]
                let rect = self.bounds;
                let optImage: UIImage? = UIImage(contentsOfFile: bundle.path(forResource: "ani-recording", ofType: "png")!)!.withRenderingMode(.alwaysOriginal)
                recordingImage = UIImageView(image: optImage)
                recordingImage.frame = CGRect(x: (rect.width - 40)/2, y: 0, width: 40, height: 40)
                
                recordingImage.image = optImage
                recordingImage.tintColor = .clear
                recordingImage.animationImages = animitedImage
                recordingImage.animationDuration = 1.0
                recordingImage.animationRepeatCount = 0
                recordingImage.startAnimating()
            }
            self.addSubview(recordingImage)
            self.bringSubviewToFront(recordingImage)
            addConstrantForRecording()
        }
        else{
            recordingImage.stopAnimating()
            recordingImage.removeFromSuperview()
        }
    }
    private func addConstrantForRecording(){
        recordingImage.translatesAutoresizingMaskIntoConstraints = false
        recordingImage.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 1.0).isActive = true
        recordingImage.widthAnchor.constraint(equalToConstant: recordingImage.bounds.width).isActive = true
        recordingImage.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        recordingImage.heightAnchor.constraint(equalToConstant: recordingImage.bounds.height).isActive = true
    }
    //Add Top Option View
    private func addTopOption(){
        topOption = EnxTopOptionView(optionList: EnxSetting.shared.getTopOptionList(), colorComponent: EnxSetting.shared.getTopOptionColor(),delegate: self)
        var rect = self.bounds;
        topOption.rect = rect
        var maxWidth : CGFloat = 0.0
        let width : CGFloat  = CGFloat(60 * EnxSetting.shared.getTopOptionList().count)
        if(rect.width > 410){
            maxWidth = 390;
        }
        else{
            maxWidth = rect.width - 20
        }
        if(width > maxWidth){
            rect.size.width = maxWidth
        }
        else{
            rect.size.width = width
        }
        rect.size.height = 50
        rect.origin.y = 5
        rect.origin.x = (self.bounds.width - rect.width)/2
        topOption.frame = rect
        topOption.layer.cornerRadius = 8.0
        self.addSubview(topOption)
        self.bringSubviewToFront(topOption)
        topOption.translatesAutoresizingMaskIntoConstraints = false
        topOption.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 1.0).isActive = true
        topOption.widthAnchor.constraint(equalToConstant: topOption.bounds.width).isActive = true
        topOption.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        topOption.heightAnchor.constraint(equalToConstant: topOption.bounds.height).isActive = true
        updateLocalViewOrigin()
    }
   
    //Parse list of connected User
    func parseEarlyJoinParticipant(_ userList : [Any]){
        for  i in  1...userList.count {
            let userdata = userList[i - 1] as! [String : Any]
            if((room.clientId! as String) == (userdata["clientId"] as! String)){
                let partList = EnxParticipantModelObject()
                partList.clientId = userdata["clientId"] != nil ? (userdata["clientId"] as! String) : ""
                partList.name = "M E"
                partList.role = userdata["role"] != nil ? (userdata["role"] as! String) : ""
                partList.isAudioMuted = userdata["audioMuted"] != nil ? (userdata["audioMuted"] as! Bool) : false
                partList.isVideoMuted = userdata["videoMuted"] != nil ? (userdata["videoMuted"] as! Bool) : false
                participantList.append(partList)
            }
            else{
                let partList = EnxParticipantModelObject()
                partList.clientId = userdata["clientId"] != nil ? (userdata["clientId"] as! String) : ""
                partList.name = userdata["name"] != nil ? (userdata["name"] as! String) : ""
                partList.role = userdata["role"] != nil ? (userdata["role"] as! String) : ""
                partList.isAudioMuted = userdata["audioMuted"] != nil ? (userdata["audioMuted"] as! Bool) : false
                partList.isVideoMuted = userdata["videoMuted"] != nil ? (userdata["videoMuted"] as! Bool) : false
                participantList.append(partList)
            }
        }
    }
    func updateParticipantList(_ userdetails : [String : Any]){
        print("user Data \(userdetails)")
        let userInfo = userdetails["user"] as! [String : Any]
        for (index,partList) in participantList.enumerated(){
            if(partList.clientId == (userInfo["clientId"] as! String)){
                partList.isAudioMuted = userInfo["audioMuted"] != nil ? (userInfo["audioMuted"] as! Bool) : false
                partList.isVideoMuted = userInfo["videoMuted"] != nil ? (userInfo["videoMuted"] as! Bool) : false
                participantList.remove(at: index)
                participantList.insert(partList, at: index)
                NotificationCenter.default.post(name: Notification.Name("UserUpdate"), object: partList, userInfo: nil)
                break
            }
        }
    }
    //Create Menu List
    func createMenuList(_ menuList : [MenuOptions]) {
        for list in menuList{
            if(list == .recording){
                let recording = EnxMenuOptionObject()
                recording.name = "Start Recording"
                recording.isSelected = false
                recording.optionTag = .recording
                if(getUserRole()){
                    moreOptionList.append(recording)
                }
            }
           else if(list == .muteRoom){
               let muteRoom = EnxMenuOptionObject()
               muteRoom.name = "Mute Room"
               muteRoom.isSelected = false
               muteRoom.optionTag = .muteRoom
               if(getUserRole()){
                   moreOptionList.append(muteRoom)
               }
            }
            else if(list == .switchAT){
                let switchAT = EnxMenuOptionObject()
                switchAT.name = "Switch Layout"
                switchAT.isSelected = false
                switchAT.optionTag = .switchAT
                moreOptionList.append(switchAT)
             }
        }
    }
    func updateMenuOptions( _ isSelected : Bool , eventType : MenuOptions){
        for (index, optionItem) in moreOptionList.enumerated(){
            if(optionItem.optionTag == eventType){
                moreOptionList.remove(at: index)
                optionItem.isSelected = isSelected
                moreOptionList.insert(optionItem, at: index)
                NotificationCenter.default.post(name: Notification.Name("updateMenu"), object: optionItem, userInfo: nil)
                break
            }
        }
    }
    //Parse request data
    func parseTheRequestList(_ requestList : [Any], isApproved : Bool){
        for reqInfo in requestList{
            let tempDict = reqInfo as! [String : Any]
            let requestFloorData = EnxRequestModel()
            requestFloorData.clientID = (tempDict["clientId"] as! String)
            requestFloorData.name = (tempDict["name"] as! String)
            requestFloorData.status = isApproved ? "accepted" : "not accepted"
            floorRequestList.append(requestFloorData)
        }
        guard topOption != nil && floorRequestList.count > 0  else{
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            topOption.updateRequestCount(requestCount: String(floorRequestList.count))
        }
       
    }
    func getRequestsList(_ requestList : [EnxRequestModel]){
        for request in requestList{
            floorRequestList.append(request)
        }
        guard topOption != nil && floorRequestList.count > 0  else{
            return
        }
        topOption.updateRequestCount(requestCount: String(floorRequestList.count))
    }
    func removeReqiestList(_ clientId : String){
        for (index,list) in floorRequestList.enumerated(){
            if(list.clientID == clientId){
                floorRequestList.remove(at: index)
            }
        }
        topOption.updateRequestCount(requestCount: String(floorRequestList.count))
    }
    func updateRequest(_ clientId : String, status : String){
            for (index,list) in floorRequestList.enumerated(){
                if(list.clientID == clientId){
                    if(status == "approved"){
                        floorRequestList.remove(at: index)
                        list.status = "accepted"
                        floorRequestList.insert(list, at: index)
                    }
                    else{
                        floorRequestList.remove(at: index)
                    }
                    break
                }
            }
        guard topOption != nil else{
            return
        }
        topOption.updateRequestCount(requestCount: String(floorRequestList.count))
    }
    func changeStatusForRequestFloor(_ status : String){
        guard topOption != nil else{
            return
        }
        let button = topOption.getRequestFloorButton()
        if let bundle = EnxSetting.shared.getPath(){
            button.setImage( status == "noRequest" ? UIImage(contentsOfFile: bundle.path(forResource: "raiseHand", ofType: "png")!) : status == "accepted" ? UIImage(contentsOfFile: bundle.path(forResource: "finishedRaise", ofType: "png")!) : UIImage(contentsOfFile: bundle.path(forResource: "cancelRaise", ofType: "png")!) , for: .normal)
        }
    }
    //Set Chat Room Type
    func setWhichChatRoom(_ chatRoom : String){
        whichCharRoom = chatRoom
    }
    //get Chat Room Type
    func getWhichChatRoom() -> String{
        return whichCharRoom
    }
    private func updateUserListforChatdata(_ repId : String , isView : Bool){
       for (index ,list) in participantList.enumerated() {
         if(list.clientId == repId)
           {
            if(isView){
                list.chatCount =  0
            }
            else{
                list.chatCount =  list.chatCount + 1
            }
             participantList.remove(at: index)
             participantList.insert(list, at: index)
           NotificationCenter.default.post(name: NSNotification.Name("UserUpdate"), object: list, userInfo: nil)
           break;
                  }
              }
          }
    func removeAudioPOPover(){
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
            self.enxAudioMediaView.frame = CGRect(x: self.center.x, y: self.center.y, width: 0, height: 0)
        }, completion: { _ in
            self.enxAudioMediaView.removeFromSuperview()
        })
    }
}

//MARK: - Video Events
extension EnxVideoViewClass : EnxRoomDelegate,EnxStreamDelegate{
    ///Room Connected
    public func room(_ room: EnxRoom?, didConnect roomMetadata: [AnyHashable : Any]?) {
        self.room = room!
        if(localStream != nil){
            self.room.publish(localStream)
            localStream.attachRenderer(localPlayer)
        }
        loader.changeLoderMessage(message: "Preaparing.....")
        let roomInfo = roomMetadata!["room"] as! [String : Any]
        let settingDet = roomInfo["settings"] as! [String : Any]
        roomMode = (settingDet["mode"] as! String)
        print("room MEta Data \(settingDet["mode"] as! String)")
        addBottomOption()
        addTopOption()
        createMenuList([.recording,.muteRoom,.switchAT])
        guard roomMetadata?["userList"] as? [Any] != nil else{
            return
        }
        parseEarlyJoinParticipant(roomMetadata?["userList"] as! [Any])
        parseTheRequestList(roomMetadata!["approvedHands"] as! [Any],isApproved: true)
        parseTheRequestList(roomMetadata!["raisedHands"] as! [Any],isApproved: false)
        //update the setting flag
        EnxSetting.shared.connectionEstablishSuccess(true)
        EnxSetting.shared.updateRoomMode(withMode: roomMode)
        EnxSetting.shared.updateUserRole(withRole: getUserRole())
    }
    /// Room Connection failed with cause
    public func room(_ room: EnxRoom?, didError reason: [Any]?) {
        //Room error
        delegate?.connectError(reason: reason)
        EnxSetting.shared.connectionEstablishSuccess(false)

    }
    /// Room Event has failed
    public func room(_ room: EnxRoom?, didEventError reason: [Any]?) {
        guard let resDict = reason?[0] as? [String : Any], reason!.count>0 else {
            return
        }
        let eventError = resDict["desc"]
        EnxToastView.showInParent(parentView: self, withText: eventError as! String, forDuration: 1.0)
       // delegate?.roomEventErre(eventError as! String)
        //print("Event Error \(resDict)")
    }
    /// Remote stream added , now user need to subscribe same stream
    public func room(_ room: EnxRoom?, didAddedStream stream: EnxStream?) {
        guard self.room != nil else {return}
        self.room.subscribe(stream!)
    }
    /// self stream has published success
    public func room(_ room: EnxRoom?, didPublishStream stream: EnxStream?) {

    }
    /// All available remote stream has subscribe Success
    public func room(_ room: EnxRoom?, didSubscribeStream stream: EnxStream?) {
        print(stream?.streamId as Any)
    }
    /// Any other user has join after me join
    public func room(_ room: EnxRoom?, userDidJoined Data: [Any]?) {
       //To Do
        guard Data != nil && Data!.count > 0 else{
            return
        }
        let partList = EnxParticipantModelObject()
        let particData = Data![0] as! [String : Any]
        partList.clientId = particData["clientId"] != nil ? (particData["clientId"] as! String) : ""
        partList.name = particData["name"] != nil ? (particData["name"] as! String) : ""
        partList.role = particData["role"] != nil ? (particData["role"] as! String) : ""
        partList.isAudioMuted = particData["audioMuted"] != nil ? (particData["audioMuted"] as! Bool) : false
        partList.isVideoMuted = particData["videoMuted"] != nil ? (particData["videoMuted"] as! Bool) : false
        participantList.append(partList)
        NotificationCenter.default.post(name: Notification.Name("userConnected"), object: partList, userInfo: nil)
    }
    /// Any remote user got disconnected
    public func room(_ room: EnxRoom?, userDidDisconnected Data: [Any]?) {
        //To Do
        guard Data != nil && Data!.count > 0 else{
            return
        }
        let particData = Data![0] as! [String : Any]
        for (index,partList) in participantList.enumerated(){
            if(partList.clientId == (particData["clientId"] as! String)){
                participantList.remove(at: index)
                NotificationCenter.default.post(name: Notification.Name("userDisconnected"), object: partList, userInfo: nil)
                break
            }
        }
        if(roomMode != "group"){
            removeReqiestList(particData["clientId"] as! String)
            guard enxReqPopOver != nil else{
                return
            }
            enxReqPopOver.removeReqiestList(particData["clientId"] as! String)
            
        }
    }
    /// Active talker list
    public func room(_ room: EnxRoom?, didActiveTalkerList Data: [Any]?) {

    }
    public func room(_ room: EnxRoom?, didActiveTalkerView view: UIView?) {
        loader.removeLoader()
        if(!isSpeaker){
            guard self.room != nil else { return }
            self.room.switchMediaDevice("Speaker")
            isSpeaker = true
        }
        guard let view = view else {
            return
        }
        self.addSubview(view)
        view.frame = self.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.sendSubviewToBack(view)
        
    }
    //MARK: - Lecture Mode Delegates
    /// Delegates for Moderator
    public func didFloorRequestReceived(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        let requestFloorData = EnxRequestModel()
        requestFloorData.clientID = (tempDict["clientId"] as! String)
        requestFloorData.name = (tempDict["name"] as! String)
        requestFloorData.status = "not accepted"
        getRequestsList([requestFloorData])
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.getRequestsList([requestFloorData])
       //to Do
    }
    /// This delegate method will notify to all available modiatore, Once any participent has finished there floor request
    public func didFinishedFloorRequest(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        updateRequest((tempDict["clientId"] as! String), status: "finished")
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.updateRequest((tempDict["clientId"] as! String), status: "finished")
    }
    /// This delegate method will notify to all available modiatore, Once any participent has cancled there floor request
    public func didCancelledFloorRequest(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0  else {
            return
        }
        updateRequest((tempDict["clientId"] as! String), status: "cancel")
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.updateRequest((tempDict["clientId"] as! String), status: "cancel")
    }
    ///This delegate invoke when Moderator accepts the floor request.
    public func didGrantedFloorRequest(_ Data: [Any]?) {
        //to Do
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if (getUserRole()){
            updateRequest((tempDict["clientId"] as! String), status: "approved")
            guard enxReqPopOver != nil else{
                return
            }
            enxReqPopOver.updateRequest((tempDict["clientId"] as! String), status: "approved")
        }
        else{
            currentFloorStatus = "accepted"
            changeStatusForRequestFloor(currentFloorStatus)
        }
    }
    /// This delegate invoke when Moderator deny the floor request.
    public func didDeniedFloorRequest(_ Data: [Any]?) {
        //to Do
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if (getUserRole()){
            updateRequest((tempDict["clientId"] as! String), status: "deny")
            guard enxReqPopOver != nil else{
                return
            }
            enxReqPopOver.updateRequest((tempDict["clientId"] as! String), status: "deny")
        }
        else{
            currentFloorStatus = "noRequest"
            changeStatusForRequestFloor(currentFloorStatus)
        }
    }
    /// This delegate invoke when Moderator release the floor request.
    public func didReleasedFloorRequest(_ Data: [Any]?) {
        //to Do
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if (getUserRole()){
            updateRequest((tempDict["clientId"] as! String), status: "release")
            guard enxReqPopOver != nil else{
                return
            }
            enxReqPopOver.updateRequest((tempDict["clientId"] as! String), status: "release")
        }
        else{
            currentFloorStatus = "noRequest"
            changeStatusForRequestFloor(currentFloorStatus)
        }
    }
    /// Process floor request
    public func didProcessFloorRequested(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        guard let requestDict = tempDict["request"] as? [String : Any] else {
            return
        }
        guard let paramsDict = requestDict["params"] as? [String : Any], enxReqPopOver != nil else {
            return
        }
        if(paramsDict["action"] as! String == "grantFloor"){
            updateRequest((paramsDict["clientId"] as! String), status: "approved")
            
        }
        else if(paramsDict["action"] as! String == "denyFloor"){
            updateRequest((paramsDict["clientId"] as! String), status: "deny")
        }
        else if(paramsDict["action"] as! String == "releaseFloor"){
            updateRequest((paramsDict["clientId"] as! String), status: "releaseFloor")
        }
        guard enxReqPopOver != nil else{
            return
        }
        if(paramsDict["action"] as! String == "grantFloor"){
            enxReqPopOver.updateRequest((paramsDict["clientId"] as! String), status: "approved")
        }
        else if(paramsDict["action"] as! String == "denyFloor"){
            enxReqPopOver.updateRequest((paramsDict["clientId"] as! String), status: "deny")
        }
        else if(paramsDict["action"] as! String == "releaseFloor"){
            enxReqPopOver.updateRequest((paramsDict["clientId"] as! String), status: "releaseFloor")
        }
        
    }
    //MARK: - Delegates for Participant
    /// This Delegate will notify to user about Floor requeted response.
    public func didFloorRequested(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if(tempDict["msg"] as! String == "Success"){
            currentFloorStatus = "waitForApproval"
            changeStatusForRequestFloor(currentFloorStatus)
        }
        else{
            currentFloorStatus = "noRequest"
            changeStatusForRequestFloor(currentFloorStatus)
        }
    }
    /// This ACK method for Participent , When he/she will finished their request floor
    /// after request floor accepted by any modiatore
    public func didFloorFinished(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if(tempDict["msg"] as! String == "Success"){
            currentFloorStatus = "noRequest"
            changeStatusForRequestFloor(currentFloorStatus)
        }
    }
    /// This ACK method for Participent , When he/she will cancle their request floor
    public func didFloorCancelled(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if(tempDict["msg"] as! String == "Success"){
            currentFloorStatus = "noRequest"
            changeStatusForRequestFloor(currentFloorStatus)
        }
        else{
            currentFloorStatus = "waitForApproval"
            changeStatusForRequestFloor(currentFloorStatus)
        }
    }
    //MARK: - Audio/Video
    /// This Delegate will notify to current User If any user has stoped There Audio or current user Video
    public func didAudioEvents(_ data: [AnyHashable : Any]?) {
        //To Do
        var isAudioMute : Bool = false
        if(data!["msg"] as! String == "Audio Off"){
            isAudioMute = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard self.bottomView != nil else{
                return
            }
            bottomView.muteAudio(flag: isAudioMute)
            for (index,iten) in participantList.enumerated(){
                if(iten.clientId == self.room.clientId! as String){
                    iten.isAudioMuted = isAudioMute
                    participantList.remove(at: index)
                    participantList.insert(iten, at: index)
                    NotificationCenter.default.post(name: Notification.Name("UserUpdate"), object: iten, userInfo: nil)
                    break
                }
            }
        }
    }
    public func didVideoEvents(_ data: [AnyHashable : Any]?) {
        var isVideoMuted : Bool = false
        if(data!["msg"] as! String == "Video Off"){
            isVideoMuted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard self.bottomView != nil else{
                return
            }
            bottomView.muteVideo(flag: isVideoMuted)
            for (index,iten) in participantList.enumerated(){
                if(iten.clientId == self.room.clientId! as String){
                    iten.isVideoMuted = isVideoMuted
                    participantList.remove(at: index)
                    participantList.insert(iten, at: index)
                    NotificationCenter.default.post(name: Notification.Name("UserUpdate"), object: iten, userInfo: nil)
                    break
                }
            }
        }
    }
    //MARK: - Recording
    public func roomRecord(on Data: [Any]?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard self.bottomView != nil else{
                    return
            }
            if(getUserRole()){
                updateMenuOptions(true, eventType: .recording)
            }
            recordingUi(true)
        }
    }
    public func roomRecordOff(_ Data: [Any]?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard self.bottomView != nil else{
                return
            }
            if(getUserRole()){
                updateMenuOptions(false, eventType: .recording)
            }
            recordingUi(false)
        }
    }
    public func didNotifyDeviceUpdate(_ updates: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard self.bottomView != nil else{
                return
            }
            bottomView.audiochnage(mediaName: updates)
        }
    }
    public func room(_ room: EnxRoom?, didScreenShareStarted stream: EnxStream?) {
        //to Do
    }
    public func room(_ room: EnxRoom?, didScreenShareStopped stream: EnxStream?) {
        //to Do
    }
    public func room(_ room: EnxRoom, didMessageReceived data: [Any]?) {
        let chatModel = EnxChatModel()
        let chatValue = data![0] as! [String : Any]
        print("chat data \(chatValue)");
        chatModel.senderName = (chatValue["sender"] as! String)
        chatModel.message = (chatValue["message"] as! String)
        chatModel.senderID = (chatValue["senderId"] as! String)
        chatModel.messageType = .receive
        chatModel.date = Date()
        if((chatValue["broadcast"] as! Bool) == true){
            chatModel.isBroadCase = true
            EnxSetting.shared.saveGroupChatData(chatModel)
            if(getWhichChatRoom() == "groupchat"){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.updateChatMessage(chatModel)
            }
            else{
                messageCount += 1
                guard bottomView != nil else{
                    return
                }
                bottomView.updategroupChatCount(messageCount)
            }
        }
        else{
            chatModel.isBroadCase = false
            EnxSetting.shared.savePrivateChat(chatModel)
           
            if(getWhichChatRoom() == chatModel.senderID!){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.updateChatMessage(chatModel)
            }
            else{
                updateUserListforChatdata(chatModel.senderID, isView: false)
            }
        }
    }
    public func room(_ room: EnxRoom?, didSetTalkerCount Data: [Any]?) {
        //Taker callback
    }
    //whiteboard started
    
    public func room(_ room: EnxRoom?, didCanvasStarted stream: EnxStream?) {
        //to Do
    }
    //whiteboard Stop
    public func room(_ room: EnxRoom?, didCanvasStopped stream: EnxStream?) {
        //to Do
    }
    //EnxStream Delegate
    
    public func stream(_ stream: EnxStream?, didHardVideoMute data: [Any]?) {
        //To Do
    }
    public func stream(_ stream: EnxStream?, didHardVideoUnMute data: [Any]?) {
        ///To Do
    }
    public func stream(_ stream: EnxStream?, didRemoteStreamVideoMute data: [Any]?) {
        guard data != nil && data!.count > 0 else{
            return
        }
        updateParticipantList(data![0] as! [String : Any])
    }
    public func stream(_ stream: EnxStream?, didRemoteStreamVideoUnMute data: [Any]?) {
        guard data != nil && data!.count > 0 else{
            return
        }
        updateParticipantList(data![0] as! [String : Any])
    }
    public func stream(_ stream: EnxStream?, didRemoteStreamAudioMute data: [Any]?) {
        guard data != nil && data!.count > 0 else{
            return
        }
        updateParticipantList(data![0] as! [String : Any])
    }
    public func stream(_ stream: EnxStream?, didRemoteStreamAudioUnMute data: [Any]?) {
        guard data != nil && data!.count > 0 else{
            return
        }
        updateParticipantList(data![0] as! [String : Any])
    }
    public func didhardMute(_ Data: [Any]?) {
        if let data = Data{
            if(data.count > 0){
                if data[0] is String{
                    return
                }
                else{
                    let dict = data[0] as! [String : Any]
                    if((dict["result"] as! Int) == 0){
                        updateMenuOptions(true, eventType: .muteRoom)
                    }
                }
            }
        }
    }
    public func didhardUnMute(_ Data: [Any]?) {
        //to Do
        if let data = Data{
            if(data.count > 0){
                if data[0] is String{
                    return
                }
                else{
                    let dict = data[0] as! [String : Any]
                    if((dict["result"] as! Int) == 0){
                        updateMenuOptions(false, eventType: .muteRoom)
                    }
                }
            }
        }
    }
    public func didHardMuteReceived(_ Data: [Any]?) {
        //To Do
        /*if let data = Data{
            if(data.count > 0){
                if data[0] is String{
                    return
                }
                else{
                    let dict = data[0] as! [String : Any]
                    if((dict["status"] as! Int) == 1){
                        if(getUserRole()){
                            bottomView.muteUnMuteRoom(isMuted: true)
                        }
                    }
                }
            }
        }*/
        EnxToastView.showInParent(parentView: self, withText: "The host has unmuted all participants", forDuration: 1.0)
    }
    public func didHardunMuteReceived(_ Data: [Any]?) {
        //to Do
       /* if let data = Data{
            if(data.count > 0){
                if data[0] is String{
                    return
                }
                else{
                    let dict = data[0] as! [String : Any]
                    if((dict["status"] as! Int) == 0){
                        if(getUserRole()){
                            bottomView.muteUnMuteRoom(isMuted: false)
                        }
                    }
                }
            }
        }*/
     
        EnxToastView.showInParent(parentView: self, withText: "The host has unmuted all participants", forDuration: 1.0)
        
    }
    //Room disconnected With cause
    public func didRoomDisconnect(_ response: [Any]?) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: UIDevice.orientationDidChangeNotification.rawValue), object: nil)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        delegate?.disconnect(response: response)
        EnxSetting.shared.connectionEstablishSuccess(false)
        EnxSetting.shared.cleanChatHistory()
    }
}
//MARK: - CallBack BottonView
//CallBack BottonView
extension EnxVideoViewClass : EnxBottomOptionDelegate{
    //open audio media list
    func openAudioMediaList() {
        guard self.room != nil else { return }
        var mediaList : [EnxAudioMediaModel] = []
        let mList = self.room.getDevices()
        for items in mList{
            let audioModel = EnxAudioMediaModel()
            audioModel.mediaName = (items as! String)
            self.room.getSelectedDevice() == (items as! String) ? (audioModel.isSelected = true) : (audioModel.isSelected = false)
            mediaList.append(audioModel)
        }
        enxAudioMediaView = EnxAudioMediaListView(audioMediaList: mediaList,delegate: self)
        enxAudioMediaView.frame = CGRect(x: self.center.x, y: self.center.y, width: 0, height: 0)
        enxAudioMediaView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxAudioMediaView)
        self.bringSubviewToFront(enxAudioMediaView)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                   self.enxAudioMediaView.frame = self.bounds
                self.layoutIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
                    self.enxAudioMediaView.updateListViewAlpha()
                }
            }, completion: nil)
    }
    //Open Group Chat windoe
    func sendGroupChat() {
        //enxChatView
        enxChatView = EnxChatViewListView(reciepantID: "groupchat", delegate: self)
        var rect = self.bounds
        rect.size.width = 0.0
        enxChatView.frame = rect
        enxChatView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxChatView)
        self.bringSubviewToFront(enxChatView)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                var rect =  self.enxChatView.frame
                rect.size.width = self.bounds.width
                self.enxChatView.frame = rect
                self.layoutIfNeeded()
        }, completion: { _ in
            self.enxChatView.updateListViewAlpha()
            self.setWhichChatRoom("groupchat")
            self.enxChatView.featchOldChat()
            self.messageCount = 0
            guard self.bottomView != nil else{
                return
            }
            self.bottomView.updategroupChatCount(self.messageCount)
        })
    }
    func muteAudio(_ flag: Bool) {
        guard self.localStream != nil else { return }
        localStream.muteSelfAudio(!flag)
    }
    
    func muteVideo(_ flag: Bool) {
        guard self.localStream != nil else { return }
        localStream.muteSelfVideo(!flag)
    }
    
    func switchCamera(_ flag: Bool) {
        guard self.localStream != nil else { return }
        localStream.switchCamera()
    }
    
    func changeAudio(_ audioMedia: String) {
        guard self.room != nil else { return }
        room.switchMediaDevice(audioMedia)
    }
    
    func disconnect(_ disconnect: Bool) {
        guard self.room != nil else { return }
        room.disconnect()
    }
}
//MARK: - CallBack TopView
extension EnxVideoViewClass : EnxTopOptionDelegate{
    func showRequestList(_ button : UIButton) {
        if(floorRequestList.count == 0){
            EnxToastView.showInParent(parentView: self, withText: "No Request Found", forDuration: 1.0)
            return
        }
        enxReqPopOver = EnxrequestPopOverView(requestDataList: floorRequestList, delegate : self)
        enxReqPopOver.frame = CGRect(x: self.center.x, y: self.center.y, width: 0, height: 0)
        enxReqPopOver.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxReqPopOver)
        self.bringSubviewToFront(enxReqPopOver)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                self.enxReqPopOver.frame = self.bounds
                self.layoutIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
                    self.enxReqPopOver.updateAlpha()
                }
            }, completion: nil)
    }
    func requestFloor() {
        guard self.room != nil else { return }
        currentFloorStatus == "noRequest" ? self.room.requestFloor() : currentFloorStatus == "accepted" ?  self.room.finishFloor() : self.room.cancelFloor()
    }
    
   //Show Participant List
    func showParticipantList(){
        enxparticipantView = EnxParticipantListView(listOfParticipant: participantList.count > 0 ? participantList : [] , delegate: self, role: getUserRole() ? "moderator":"participant",selfClierntID: (room.clientId! as String))
        
        var rect = self.bounds
        rect.size.width = 0.0
        enxparticipantView.frame = rect
        enxparticipantView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxparticipantView)
        self.bringSubviewToFront(enxparticipantView)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                var rect =  self.enxparticipantView.frame
                rect.size.width = self.bounds.width
                self.enxparticipantView.frame = rect
                self.layoutIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                        self.enxparticipantView.updateListViewAlpha()
                    }
                }, completion: nil)
    }
    //Show Menu list
    func showMenuList(){
        enxMenuView = EnxMenuView(listOfOptions: moreOptionList, delegate: self)
        enxMenuView.frame = CGRect(x: self.center.x, y: self.center.y, width: 0, height: 0)
        enxMenuView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxMenuView)
        self.bringSubviewToFront(enxMenuView)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
            self.enxMenuView.frame = self.bounds
                self.layoutIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
                        self.enxMenuView.updateListViewAlpha()
                    }
                }, completion: nil)
    }
}
//MARK: - CallBack participant View
    //CallBack from participant View
extension EnxVideoViewClass : EnxParticipantViewDelegate{
    func clickToMuteUnMuteSingleAudio(_ clientID: String, isMuted: Bool) {
        guard self.room != nil else { return }
        if(clientID == room.clientId! as String){
            guard self.localStream != nil else { return }
            localStream.muteSelfAudio(!isMuted)
            return
        }
        if(isMuted){
            self.room.hardUnmuteUserAudio(clientID)
        }
        else{
            self.room.hardMuteUserAudio(clientID)
        }
    }
    
    func clickToMuteUnMuteSingleVideo(_ clientID: String, isMuted: Bool) {
        guard self.room != nil else { return }
        if(clientID == room.clientId! as String){
            guard self.localStream != nil else { return }
            localStream.muteSelfVideo(!isMuted)
            return
        }
        if(isMuted){
            self.room.hardUnmuteUserVideo(clientID)
        }
        else{
            self.room.hardMuteUserVideo(clientID)
        }
    }
    
    func clickToDisconnectSingleUser(_ clientID: String) {
        guard self.room != nil else { return }
        if(clientID == room.clientId! as String){
            room.disconnect()
            return
        }
        self.room.dropUser([clientID])
    }
    
    func clickToPrivateChat(_ clientID: String) {
        //guard self.room != nil else { return }
        enxChatView = EnxChatViewListView(reciepantID: clientID, delegate: self)
        var rect = self.bounds
        rect.size.width = 0.0
        enxChatView.frame = rect
        enxChatView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxChatView)
        self.bringSubviewToFront(enxChatView)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                var rect =  self.enxChatView.frame
                rect.size.width = self.bounds.width
                self.enxChatView.frame = rect
                self.layoutIfNeeded()
        }, completion: { _ in
            self.enxChatView.updateListViewAlpha()
            self.setWhichChatRoom(clientID)
            self.enxChatView.featchOldChat()
            self.updateUserListforChatdata(clientID, isView: true)
        })
    }
    
//Navigate Back
    func tapOnViewToNavigateBack(){
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                var rect =  self.enxparticipantView.frame
            rect.size.width = 0.0
                self.enxparticipantView.frame = rect
                self.layoutIfNeeded()
        }, completion: { _ in
            self.enxparticipantView.removeFromSuperview()
        })
    }
}
//MARK: - CallBack Menu View
//CallBack from Menu View
extension EnxVideoViewClass : EnxMenuViewDelegate{
    //REcording Start/Stop
    func startStopRecording(_ isRecording: Bool) {
        guard self.room != nil else { return }
        if(isRecording){
            room.stopRecord()
        }
        else{
            room.startRecord()
        }
    }
    // Room Mute/unMute
    func muteRoom(_ isMuteRoom: Bool) {
        guard self.room != nil else { return }
            if(isMuteRoom){
                room.hardUnMute()
            }
            else{
                room.hardMute()
            }
    }
    // Switch At from grid to presenter and vice versa
    func switchAtView(_ isGrid: Bool) {
        guard self.room != nil else { return }
            if(isGrid){
                self.room.switch(atView: "leader")
                updateMenuOptions(true, eventType: .switchAT)
            }
            else{
                self.room.switch(atView: "gallery")
                updateMenuOptions(false, eventType: .switchAT)
            }
    }
    //Navigate Back
    func tapOnMenuViewToNavigateBack(){
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
            self.enxMenuView.frame = CGRect(x: self.center.x, y: self.center.y, width: 0, height: 0)
        }, completion: { _ in
            self.enxMenuView.removeFromSuperview()
        })
    }
}
//MARK: - Request PopoverDelegate
//Request PopoverDelegate
extension EnxVideoViewClass : EnxRequestPopOverDelegates{
    func floorRequestAccept(_ clientId: String) {
        guard room != nil else{
            return
        }
        room.grantFloor(clientId)
    }
    
    func floorRequestDeny(_ clientId: String) {
        guard room != nil else{
            return
        }
        room.denyFloor(clientId)
    }
    
    func floorRequestRelease(_ clientId: String) {
        room.releaseFloor(clientId)
    }
    func closedPopOver() {
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
            self.enxReqPopOver.frame = CGRect(x: self.center.x, y: self.center.y, width: 0, height: 0)
        }, completion: { _ in
            self.enxReqPopOver.removeFromSuperview()
        })
    }
}
//MARK: - ChatView delegate
//Request PopoverDelegate
extension EnxVideoViewClass : EnxChatViewDelegate{
    //Send Private Chat
    func sendPrivateChat(_ chatDate: EnxChatModel) {
        guard self.room != nil else { return }
        self.room.sendMessage(chatDate.message , isBroadCast: false , recipientIDs: [chatDate.senderID!])
    }
    //Send Group Chat
    func sendGroupChat(_ chatDate: EnxChatModel) {
        guard self.room != nil else { return }
        self.room.sendMessage(chatDate.message , isBroadCast: true , recipientIDs: nil)
    }
    
    func tapOnChatViewToNavigateBack() {
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: {
                var rect =  self.enxChatView.frame
            rect.size.width = 0.0
                self.enxChatView.frame = rect
                self.layoutIfNeeded()
        }, completion: { _ in
            self.enxChatView.removeFromSuperview()
            self.setWhichChatRoom("non")
        })
    }
}
//MARK: - Audio Media delegate
//Request PopoverDelegate
extension EnxVideoViewClass : EnxMediaDelegate{
    func tapOnViewTodismiss() {
       removeAudioPOPover()
    }
    
    func switchAudioMedia(tomedia: EnxAudioMediaModel) {
        guard self.room != nil else { return }
        room.switchMediaDevice(tomedia.mediaName)
        removeAudioPOPover()
        guard enxAudioMediaView != nil else{return}
        enxAudioMediaView.removeListView()
    }
}
