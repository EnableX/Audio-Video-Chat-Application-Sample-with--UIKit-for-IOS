//
//  EnxVideoViewClass.swift
//  Enx_UIKit_iOS
//
//  Created by Enx on 07/02/22.
//

import UIKit
import EnxRTCiOS
import AVFoundation

@objc
public protocol EnxVideoStateDelegate:AnyObject {
    func disconnect(response: [Any]?)
    func connectError(reason: [Any]?)
    @objc optional func didPageSlide(_ pageName  : EnxPageSlideEventName , isShow : Bool)
    @objc optional func didUserDataReceived(_ userData : [String : Any])
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
    weak var delegate: EnxVideoStateDelegate?
    private(set) var topViewHeight : CGFloat!
    private(set) var isOptionShow : Bool = true
    private(set) var participantList : [EnxParticipantModelObject] = []
    private(set) var roomMode : String! = "group"
    private(set) var currentFloorStatus : String! = "noRequest"
    private(set) var enxReqPopOver : EnxrequestPopOverView!
    private(set) var enxChatView : EnxChatViewListView!
    private(set) var whichCharRoom : String = "non"
    private(set) var messageCount : Int = 0
    private(set) var enxAudioMediaView : EnxAudioMediaListView!
    private(set) var tempVideoPlayerView : UIView!
    private(set) var tempSharePlayerView : EnxPlayerView!
    private(set) var isShareRunning : Bool = false
    private(set) var totalSubscriberInRoom : Int = 0
    private(set)var drawTool : EnxToolBar!
    private(set)var tempAnnotedStream : EnxStream!
    private(set)var confirmationView : EnxConfirmationViewClass!
    private(set) var requestiesList : [String : [EnxRequestModel]] = [:]
    
    private(set)var isAudioMuted : Bool = false
    private(set) var isVideoMuted : Bool = false
    private(set) var isAudioOnly : Bool = false
    
    private(set) var enxMenuListView = EnxMunuListView.loadFromNib()
    private(set) var enxRoomSettingView = EnxRoomSettingPage.loadFromNib()
    private(set)var lobbyView : EnxLobbyView!
    
    private(set) var hours : Int = 00
    private(set) var minut : Int = 00
    private(set) var second : Int = 00
    private(set) var countTime : Timer!
    private(set) var player: AVAudioPlayer?
    
    private let timerLBL : UILabel = {
        let lbl = UILabel(frame: .zero)
        lbl.textColor = .white
        lbl.font = UIFont.boldSystemFont(ofSize: 12)
        lbl.textAlignment = .center
        lbl.sizeToFit()
        return lbl
    }()
    
    private let timerView : UIView = {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.lightGray.cgColor
        return view
    }()
    private let imageIcn : UIImageView = {
        let iconOpt = UIImageView()
        if let bundle = EnxSetting.shared.getPath(){
            iconOpt.image = UIImage(contentsOfFile: bundle.path(forResource: "userUnCheck", ofType: "png")!)
        }
        return iconOpt
    }()
    private let optnBtn : UIButton = {
        let btn = UIButton(type: .custom)
        return btn
    }()
    private let floorBtn : UIButton = {
        let btn = UIButton(type: .custom)
        if let bundle = EnxSetting.shared.getPath(){
            btn.setImage(UIImage(contentsOfFile: bundle.path(forResource: "raiseHand", ofType: "png")!), for: .normal)
        }
        return btn
    }()
    
    @objc
    public init(token : String, delegate : EnxVideoStateDelegate?, embedUrl : String?){
        self.token = token
        self.delegate = delegate
        super.init(frame: .zero)
        if embedUrl != nil{
            EnxSetting.shared.getDetailsFromService(embedUrl!)
        }
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
        confirmationView = EnxConfirmationViewClass()
        self.addSubview(confirmationView)
        confirmationView.frame = self.bounds
        confirmationView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        confirmationView.delegate = self
    }
    func joinRoom(){
        loader = EnxLoaderView()
        self.addSubview(loader)
        loader.frame = self.bounds
        loader.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            createlocalPlayerView()
        }
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        localNotificationService()
        guard let stream = enxrtc.joinRoom(token, delegate: self,
                                           publishStreamInfo: getLocalStreamInfo(),
                                           roomInfo: getRoomInfo(),
                                           advanceOptions: nil)
        else { return }
        localStream = stream
        localStream.delegate = self
        
        let tapGuseter = UITapGestureRecognizer(target: self, action: #selector(tapToShowAndHide))
        self.addGestureRecognizer(tapGuseter)
        tapGuseter.delegate = self
        tapGuseter.numberOfTapsRequired = 1
    }
    private func localNotificationService(){
        NotificationCenter.default.removeObserver(self)
        //Device Orientation
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceOrientationDidChange(_:)), name: NSNotification.Name(rawValue: UIDevice.orientationDidChangeNotification.rawValue), object: nil)
        //Update Bottom View observer
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateOptionViewOnTap(notification:)), name: Notification.Name(customeNotification.UpdateOptionView.rawValue), object: nil)
        
        //Send User Data
        NotificationCenter.default.addObserver(self, selector: #selector(sendUserData(notification :)), name: Notification.Name(customeNotification.SenduserData.rawValue), object: nil)
    }
    //Create local Publisher Stream
    func getLocalStreamInfo() -> [String : Any]{
        let videoSize: [String: Any] = ["minWidth": 320,
                                        "minHeight": 180,
                                        "maxWidth": 1280,
                                        "maxHeight": 720]
        let localStreamInfo: [String: Any] = ["video": true,
                                              "audio": true,
                                              "data": true,
                                              "audioMuted": isAudioMuted,
                                              "videoMuted": isVideoMuted,
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
        topViewHeight = self.safeAreaLayoutGuide.layoutFrame.origin.y + 20
        let rect = self.bounds;
        localPlayer = EnxPlayerView(localView: CGRect(x: rect.width - 130, y: topViewHeight, width: 120, height: 150))
        self.addSubview(localPlayer)
        self.bringSubviewToFront(localPlayer)
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
        guard bottomView != nil else{
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
        }, completion: { [self]_ in
            if(isOptionShow){
                bottomView.isHidden = true
            }
            else{
                bottomView.isHidden = false
            }
            isOptionShow = !isOptionShow
        })
    }
    //Orientation Changes update
    @objc func deviceOrientationDidChange(_ notification: Notification){
        if(isShareRunning){
            updateShareUI()
        }
        updateLayoutForTalker()
        updateLocalViewOrigin()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            updateButtomView()
        }
    }
    //Update Local View Origin
    private func updateLocalViewOrigin(){
        let rect = self.bounds;
        if(localPlayer != nil){
            localPlayer.frame = CGRect(x: rect.width - 130, y: topViewHeight, width: 120, height: 150)
        }
    }
    private func addBottomOption(){
        bottomView = EnxBottomOptionView(optionList: EnxSetting.shared.getBottomOptionList(),colorComponent: EnxSetting.shared.getBottomOptionColor(), delegate: self)
        var rect = self.bounds;
        bottomView.rect = rect
        var maxWidth : CGFloat = 350
        if(rect.width > 410){
            maxWidth = 390;
        }
        rect.size.width = maxWidth
        rect.size.height = 75
        rect.origin.y = self.bounds.height - rect.size.height
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            bottomView.updateParticipantList(listOfParticipant: participantList.count > 0 ? participantList : [], delegate: self, role:getUserRole() ? "moderator":"participant" , selfClierntID:(room.clientId! as String))
        }
    }
    //Update Bottom OptionView on Tap
    @objc func updateOptionViewOnTap(notification: Notification) {
        updateButtomOptOnTap()
    }
    func updateButtomOptOnTap(){
        var rect = bottomView.frame
        if(bottomView.bounds.height < 85){
            rect.origin.y = UIScreen.main.bounds.height - (UIScreen.main.bounds.height * 0.75)
            rect.size.height = UIScreen.main.bounds.height * 0.75
        }else{
            rect.size.height = 75
            rect.origin.y = self.bounds.height - rect.size.height
        }
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
            self.bottomView.frame = rect
            self.bottomView.removeConstraints(self.bottomView.constraints)
            self.bottomView.translatesAutoresizingMaskIntoConstraints = false
            self.bottomView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: 0.0).isActive = true
            self.bottomView.widthAnchor.constraint(equalToConstant: self.bottomView.bounds.width).isActive = true
            self.bottomView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            self.bottomView.heightAnchor.constraint(equalToConstant: self.bottomView.bounds.height).isActive = true
        }, completion: nil)
    }
    //Update Bottom View Once Orientation Changes
    func updateButtomView(){
        guard self.room != nil else { return }
        var rect = bottomView.frame
        if(bottomView.bounds.height > 85){
            rect.origin.y = UIScreen.main.bounds.height - (UIScreen.main.bounds.height * 0.75)
            rect.size.height = UIScreen.main.bounds.height * 0.75
            UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
                self.bottomView.frame = rect
                self.bottomView.removeConstraints(self.bottomView.constraints)
                self.bottomView.translatesAutoresizingMaskIntoConstraints = false
                self.bottomView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: 0.0).isActive = true
                self.bottomView.widthAnchor.constraint(equalToConstant: self.bottomView.bounds.width).isActive = true
                self.bottomView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
                self.bottomView.heightAnchor.constraint(equalToConstant: self.bottomView.bounds.height).isActive = true
            }, completion: nil)
        }
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
        EnxSetting.shared.setParticipantList(participantList)
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
                NotificationCenter.default.post(name: Notification.Name(customeNotification.UserUpdate.rawValue), object: partList, userInfo: nil)
                break
            }
        }
    }
    //Parse request data
    func parseTheRequestList(_ requestList : [Any], isApproved : Bool){
        var floorRequestList : [EnxRequestModel] = []
        for reqInfo in requestList{
            let tempDict = reqInfo as! [String : Any]
            let requestFloorData = EnxRequestModel(clientID: (tempDict["clientId"] as! String), name: (tempDict["name"] as! String), status: isApproved ? "accepted" : "not accepted")
            floorRequestList.append(requestFloorData)
        }
        if(floorRequestList.count > 0){
            requestiesList["User Floor Request"] = floorRequestList
        }
        updateOptionList()
    }
    //Parse the awaited User
    func parseTheAwaitedUserList(_ awaitedUsers : [Any]){
        var awaitedUsersList : [EnxRequestModel] = []
        for awaitedUser in awaitedUsers {
            let tempDict = awaitedUser as! [String : Any]
            let partList = EnxRequestModel(clientID: (tempDict["clientId"] as! String), name: (tempDict["name"] as! String), status: "not accepted")
            awaitedUsersList.append(partList)
        }
        if(awaitedUsersList.count > 0){
            requestiesList["Awaited User Request"] = awaitedUsersList
        }
        updateOptionList()
        //Handel request available
    }
    func getRequestsList(_ requestList : [EnxRequestModel]){
        if requestiesList.keys.contains(where: { $0 == "User Floor Request"}){
            var florReq = requestiesList["User Floor Request"]!
            for request in requestList{
                florReq.append(request)
            }
            requestiesList.updateValue(florReq, forKey: "User Floor Request")
        } else {
            requestiesList["User Floor Request"] = requestList
        }
        updateOptionList()
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.getRequestsList(requestList , key: "User Floor Request")
    }
    func removeReqiestList(_ clientId : String){
        if requestiesList.keys.contains(where: { $0 == "User Floor Request"}){
            var florReq = requestiesList["User Floor Request"]!
            for (index,list) in florReq.enumerated(){
                if(list.clientID == clientId){
                    florReq.remove(at: index)
                }
            }
            if(florReq.count == 0){
                if let index = requestiesList.index(forKey: "User Floor Request") {
                    requestiesList.remove(at: index)
                }
            }
            else{
                requestiesList.updateValue(florReq, forKey: "User Floor Request")
            }
        }
        updateOptionList()
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.removeReqiestList(clientId , key: "User Floor Request")
    }
    func updateRequest(_ clientId : String, status : String){
        if requestiesList.keys.contains(where: { $0 == "User Floor Request"}){
            var florReq = requestiesList["User Floor Request"]!
            for (index,list) in florReq.enumerated(){
                if(list.clientID == clientId){
                    if(status == "approved"){
                        florReq.remove(at: index)
                        list.status = "accepted"
                        florReq.insert(list, at: index)
                    }
                    else{
                        florReq.remove(at: index)
                    }
                    break
                }
            }
            if(florReq.count == 0){
                if let index = requestiesList.index(forKey: "User Floor Request") {
                    requestiesList.remove(at: index)
                }
            }
            else{
                requestiesList.updateValue(florReq, forKey: "User Floor Request")
            }
            
        }
        updateOptionList()
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.updateRequest(clientId, status: status, key: "User Floor Request")
    }
    func removeUserFromWaitingList(_ clientID : String){
        if requestiesList.keys.contains(where: { $0 == "Awaited User Request"}){
            var awaitedReq = requestiesList["Awaited User Request"]!
            for (index,list) in awaitedReq.enumerated(){
                if(list.clientID == clientID){
                    awaitedReq.remove(at: index)
                }
            }
            if(awaitedReq.count == 0){
                if let index = requestiesList.index(forKey: "Awaited User Request") {
                    requestiesList.remove(at: index)
                }
            }
            else{
                requestiesList.updateValue(awaitedReq, forKey: "Awaited User Request")
            }
        }
        updateOptionList()
        guard enxReqPopOver != nil else{
            return
        }
        enxReqPopOver.removeReqiestList(clientID , key: "Awaited User Request")
        
    }
    func changeStatusForRequestFloor(_ status : String){
        if let bundle = EnxSetting.shared.getPath(){
            floorBtn.setImage( status == "noRequest" ? UIImage(contentsOfFile: bundle.path(forResource: "raiseHand", ofType: "png")!) : status == "accepted" ? UIImage(contentsOfFile: bundle.path(forResource: "finishedRaise", ofType: "png")!) : UIImage(contentsOfFile: bundle.path(forResource: "cancelRaise", ofType: "png")!) , for: .normal)
        }
    }
    //Share Common Data
    func parseSharePremissedUpdate(_ responseData : EnxRequestModel , status : String){
        
        (status == "ScreenRequest") ? addValueForShareRequest(responseData) : addValueForCanVasRequest(responseData)
        
    }
    //insert share request
    func addValueForShareRequest(_ responseData : EnxRequestModel){
        if requestiesList.keys.contains(where: { $0 == "User Share Request"}){
                var shareReq = requestiesList["User Share Request"]!
                    shareReq.append(responseData)
                    requestiesList.updateValue(shareReq, forKey: "User Share Request")
                } else {
                    requestiesList["User Share Request"] = [responseData]
                }
                updateOptionList()
                guard enxReqPopOver != nil else{
                        return
                    }
                enxReqPopOver.getRequestsList([responseData] , key: "User Share Request")
    }
    func removeValueForShareRequest(_ clientId : String){
        if requestiesList.keys.contains(where: { $0 == "User Share Request"}){
            var shareReq = requestiesList["User Share Request"]!
            for (index,list) in shareReq.enumerated(){
                if list.clientID.caseInsensitiveCompare(clientId) == .orderedSame {
                        shareReq.remove(at: index)
                        break
                    }
                }
            if(shareReq.count == 0){
                if let index = requestiesList.index(forKey: "User Share Request"){
                    requestiesList.remove(at: index)
                }
            }
            else{
                requestiesList.updateValue(shareReq, forKey: "User Share Request")
            }
        }
        updateOptionList()
        guard enxReqPopOver != nil else{
                return
            }
        enxReqPopOver.removeReqiestList(clientId , key: "User Share Request")
    }
    func updateValueForShareRequest(_ clientId : String){
        if requestiesList.keys.contains(where: { $0 == "User Share Request"}){
                    var florReq = requestiesList["User Share Request"]!
                    for (index,list) in florReq.enumerated(){
                        if list.clientID.caseInsensitiveCompare(clientId) == .orderedSame{
                            florReq.remove(at: index)
                            list.status = "accepted"
                            florReq.insert(list, at: index)
                            break
                        }
                    }
                    if(florReq.count == 0){
                        if let index = requestiesList.index(forKey: "User Share Request") {
                            requestiesList.remove(at: index)
                        }
                    }
                    else{
                        requestiesList.updateValue(florReq, forKey: "User Share Request")
                    }
                   
                }
                updateOptionList()
                guard enxReqPopOver != nil else{
                    return
                }
                enxReqPopOver.updateRequest(clientId, status: "accepted" , key: "User Share Request")
    }
    //insert Canvas request
    func addValueForCanVasRequest(_ responseData : EnxRequestModel){
        if requestiesList.keys.contains(where: { $0 == "User Canvas Request"}){
                    var canVasReq = requestiesList["User Canvas Request"]!
                   canVasReq.append(responseData)
                    requestiesList.updateValue(canVasReq, forKey: "User Canvas Request")
                } else {
                    requestiesList["User Canvas Request"] = [responseData]
                }
                updateOptionList()
                guard enxReqPopOver != nil else{
                        return
                    }
                enxReqPopOver.getRequestsList([responseData] , key: "User Canvas Request")
    }
    func removeValueForCanvasRequest(_ clientId : String){
        if requestiesList.keys.contains(where: { $0 == "User Canvas Request"}){
            var shareReq = requestiesList["User Canvas Request"]!
            for (index,list) in shareReq.enumerated(){
                if list.clientID.caseInsensitiveCompare(clientId) == .orderedSame {
                        shareReq.remove(at: index)
                        break
                    }
                }
            if(shareReq.count == 0){
                if let index = requestiesList.index(forKey: "User Canvas Request"){
                    requestiesList.remove(at: index)
                }
            }
            else{
                requestiesList.updateValue(shareReq, forKey: "User Canvas Request")
            }
        }
        updateOptionList()
        guard enxReqPopOver != nil else{
                return
            }
        enxReqPopOver.removeReqiestList(clientId , key: "User Canvas Request")
    }
    func updateValueForCanvasRequest(_ clientId : String){
        if requestiesList.keys.contains(where: { $0 == "User Canvas Request"}){
                    var florReq = requestiesList["User Canvas Request"]!
                    for (index,list) in florReq.enumerated(){
                        if list.clientID.caseInsensitiveCompare(clientId) == .orderedSame{
                            florReq.remove(at: index)
                            list.status = "accepted"
                            florReq.insert(list, at: index)
                            break
                        }
                    }
                    if(florReq.count == 0){
                        if let index = requestiesList.index(forKey: "User Canvas Request") {
                            requestiesList.remove(at: index)
                        }
                    }
                    else{
                        requestiesList.updateValue(florReq, forKey: "User Canvas Request")
                    }
                   
                }
                updateOptionList()
                guard enxReqPopOver != nil else{
                    return
                }
                enxReqPopOver.updateRequest(clientId, status: "accepted" , key: "User Canvas Request")
    }
    func getName(_ clientId : String) -> String{
        var name : String!
        for list in participantList{
            if list.clientId.caseInsensitiveCompare(clientId) == .orderedSame{
                name = list.name
                break
            }
        }
        return name
    }
    func updateOptionList(){
        if !requestiesList.keys.contains(where: { $0 == "User Floor Request"}){
            //EnxSetting.shared.updateMenuOptions(false, eventType: .requestList)
            EnxSetting.shared.setFloorReqUser(false)
            
        }else{
            //EnxSetting.shared.updateMenuOptions(true, eventType: .requestList)
            EnxSetting.shared.setFloorReqUser(true)
        }
        if !requestiesList.keys.contains(where: { $0 == "Awaited User Request"}){
            //EnxSetting.shared.updateMenuOptions(false, eventType: .lobby)
            EnxSetting.shared.setAwaitedUser(false)
        }else{
            //EnxSetting.shared.updateMenuOptions(true, eventType: .lobby)
            EnxSetting.shared.setAwaitedUser(true)
        }
        if !requestiesList.keys.contains(where: { $0 == "User Share Request"}){
            //EnxSetting.shared.updateMenuOptions(false, eventType: .requestList)
            EnxSetting.shared.setShareReqUser(false)
            
        }else{
            //EnxSetting.shared.updateMenuOptions(true, eventType: .requestList)
            EnxSetting.shared.setShareReqUser(true)
        }
        if !requestiesList.keys.contains(where: { $0 == "User Canvas Request"}){
            //EnxSetting.shared.updateMenuOptions(false, eventType: .requestList)
            EnxSetting.shared.setCanvasReqUser(false)
            
        }else{
            //EnxSetting.shared.updateMenuOptions(true, eventType: .requestList)
            EnxSetting.shared.setCanvasReqUser(true)
        }
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            if(!EnxSetting.shared.getisUserAwaited() && !EnxSetting.shared.getisUserInFloorReq() && !EnxSetting.shared.getisShareReq() && !EnxSetting.shared.getisCanvas()){
                bottomView.moreOpt(false)
            }else{
                bottomView.moreOpt(true)
            }
            if(!EnxSetting.shared.getisUserInFloorReq() && !EnxSetting.shared.getisShareReq() && !EnxSetting.shared.getisCanvas()){
                EnxSetting.shared.updateMenuOptions(false, eventType: .requestList)
            }else{
                EnxSetting.shared.updateMenuOptions(true, eventType: .requestList)
            }
            if(!EnxSetting.shared.getisUserAwaited()){
                EnxSetting.shared.updateMenuOptions(false, eventType: .lobby)
            }else{
                EnxSetting.shared.updateMenuOptions(false, eventType: .lobby)
            }
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
    //Check either subscription for file share available or not
    func isFileSubscriptionAvailable() -> Bool{
        guard self.room != nil else { return false}
        let roomInfor = self.room.roomMetadata!["room"] as! [String : Any]
        if(roomInfor["fileShareService"] != nil || (roomInfor["fileShareService"] as! [AnyObject]).count > 0){
            return true
        }
        return false
    }
    //Update usre list with new chat data
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
           NotificationCenter.default.post(name: Notification.Name(customeNotification.UserUpdate.rawValue), object: list, userInfo: nil)
           break;
                  }
              }
          }
    //Remove Auto popover if showwn
    func removeAudioPOPover(){
        UIView.animate(withDuration: 0.35, animations: { [self] in
            let moveLeft = CGAffineTransform(translationX: 0, y: 0.0)
            enxAudioMediaView.transform = moveLeft
        },completion: {_ in
            self.enxAudioMediaView.removeListView()
            self.enxAudioMediaView.removeFromSuperview()
        })
    }
    //Screen share
    @objc
    public func exitScreenShare(){
        guard self.room != nil else { return}
        self.room.exitScreenShare()
    }
    private func addShareUI(_ stream : EnxStream , isStarted : Bool){
        isShareRunning = isStarted
        if(isStarted){
            if let player = stream.enxPlayerView{
                let rect =  self.bounds
                let height = (rect.size.height/4) * 3
                player.frame = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: height)
                self.addSubview(player)
                player.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.sendSubviewToBack(player)
                player.contentMode = .scaleToFill
                tempSharePlayerView = player
                tempVideoPlayerView.frame = CGRect(x: rect.origin.x, y: rect.origin.y + height, width: rect.width, height: rect.height - height)
            }
        }
        else{
            if let player = stream.enxPlayerView{
                player.removeFromSuperview()
                tempVideoPlayerView.frame = self.bounds
                tempSharePlayerView = nil
            }
        }
        localStream.updateConfiguration(["maxVideoBW" : "200" ,"minVideoBW" : "150", "maxAudioBW" : "80","minAudioBW" : "40"])
        updateLayoutForTalker()
    }
    // UPdate layOut when share running and orientation change
    private func updateShareUI(){
        if UIDevice.current.orientation.isLandscape {
            let rect =  self.bounds
            let width = (rect.size.width/4)*3
            tempSharePlayerView.frame = CGRect(x: rect.origin.x, y: rect.origin.y, width: width, height: rect.height)
            tempVideoPlayerView.frame = CGRect(x: rect.origin.x + width, y: rect.origin.y, width: rect.width - width, height: rect.height)
        } else {
            let rect =  self.bounds
            let height = (rect.size.height/4)*3
            tempSharePlayerView.frame = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: height)
            tempVideoPlayerView.frame = CGRect(x: rect.origin.x, y: rect.origin.y + height, width: rect.width, height: rect.height - height)
        }
    }
    // Update talker layout when share share and stop or orientation changes
    private func updateLayoutForTalker(){
        guard self.room != nil else{
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            self.room.adjustLayout()
        }
    }
    //Add and remove Tool bar during annotation
    private func createToolBar(_ isRunning : Bool){
        if(isRunning){
            var rect = self.bounds;
            var maxWidth : CGFloat = 0.0
            if(rect.width > 410){
                maxWidth = 400
            }else{
                maxWidth = rect.width - 20
            }
            rect.size.height = 50
            rect.origin.y = rect.height - 50
            rect.origin.x = (rect.width - maxWidth)/2
            rect.size.width = maxWidth
            drawTool = EnxToolBar(frame: rect)
            self.addSubview(drawTool)
            self.bringSubviewToFront(bottomView)
            drawTool.translatesAutoresizingMaskIntoConstraints = false
            drawTool.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: 0.0).isActive = true
            drawTool.widthAnchor.constraint(equalToConstant: drawTool.bounds.width).isActive = true
            drawTool.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            drawTool.heightAnchor.constraint(equalToConstant: drawTool.bounds.height).isActive = true
        }
        else{
            if(drawTool != nil){
                drawTool.removeFromSuperview()
            }
        }
    }
    //Add and remove AT view and Annotated EnxPlayerView during annotation
    private func replacAtView(_ isShow : Bool, With playerView : EnxPlayerView){
        if(isShow){
            playerView.removeFromSuperview()
            tempVideoPlayerView.isHidden = false
            self.addSubview(tempVideoPlayerView)
            tempVideoPlayerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.sendSubviewToBack(tempVideoPlayerView)
            self.room.adjustLayout()
        }else{
            tempVideoPlayerView.isHidden = true
            for subView in self.subviews{
                if(subView.isKind(of: EnxATListView.self)){
                    subView.removeFromSuperview()
                }
            }
            self.addSubview(playerView)
            self.sendSubviewToBack(playerView)
            playerView.removeConstraints(playerView.constraints)
            playerView.translatesAutoresizingMaskIntoConstraints = false
            playerView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor, constant: 0.0).isActive = true
            playerView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor, constant: 0.0).isActive = true
            playerView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 0.0).isActive = true
            playerView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: 0.0).isActive = true
            playerView.layoutIfNeeded()
        }
    }
    private func navigateToHideViewBAck(_ view : UIView){
        UIView.animate(withDuration: 0.35, animations: { () -> Void in
            let moveLeft = CGAffineTransform(translationX: 0, y: 0.0)
            view.transform = moveLeft
            }, completion: { (finished: Bool) -> Void in
                view.removeFromSuperview()
            })
    }
    private func navigateToShowView(_ view : UIView){
        var rect = self.bounds
        rect.origin.x = rect.size.width
        view.frame = rect
        self.addSubview(view)
        self.bringSubviewToFront(view)
        UIView.animate(withDuration: 0.35, animations: {
            let moveLeft = CGAffineTransform(translationX: -self.bounds.width, y: 0.0)
            view.transform = moveLeft
        })
    }
    private func showTimer(){
        hours = 00
        minut = 00
        second = 00
        timerLBL.text = "00:00:00"
        timerLBL.sizeToFit()
        timerView.addSubview(timerLBL)
        self.addSubview(timerView)
        self.bringSubviewToFront(timerView)
        timerView.anchor(top: self.safeAreaLayoutGuide.topAnchor, left: self.leftAnchor, bottom: nil, right: nil, paddingTop: 10, paddingLeft: 20, paddingBottom: 0, paddingRight: 0, width: 80, height: 40, enableInsets: false)
        
        timerLBL.anchor(top: timerView.topAnchor, left: timerView.leftAnchor, bottom: timerView.bottomAnchor, right: timerView.rightAnchor, paddingTop: 10, paddingLeft: 10, paddingBottom: 10, paddingRight: 10, width: 00, height: 20, enableInsets: false)
        countTime = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] timer in
            if(second < 59){
                second += 1
            }
            else{
                second = 0
                minut += 1
            }
            if(minut > 59){
                minut = 0
                hours += 1
            }
            var secondsText : String = "00"
            var minutsText : String = "00"
            var hoursText : String = "00"
            
            if(second < 10){
                secondsText = "0" + String(second)
            }
            else{
                secondsText =  String(second)
            }
            if(minut < 10){
                minutsText = "0" + String(minut)
            }
            else{
                minutsText =  String(minut)
            }
            if(hours < 10){
                hoursText = "0" + String(hours)
            }
            else{
                 hoursText =  String(hours)
            }
            timerLBL.text = hoursText + ":" + minutsText + ":" + secondsText
            timerLBL.sizeToFit()
        }
    }
    func playSound(_ audioFile : String) {
        let url = URL(fileURLWithPath: audioFile)
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 15
            player?.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    @objc
    func sendUserData(notification: Notification){
        let enxSendUserData = notification.object as! EnxSendUserDataModel
        guard self.room != nil else {return}
        self.room.sendUserData(enxSendUserData.userData!, isBroadCast: enxSendUserData.isBroadCase!, recipientIDs: enxSendUserData.clientList)
    }
    func checkIsRoomKnockEnable() -> Bool{
        guard self.room != nil else{
            return false
        }
        if let room : [String : Any] = room.roomMetadata!["room"] as? [String : Any]{
            if let setting : [String : Any] = room["settings"] as? [String : Any] {
                if let knock = setting["knock"]{
                    EnxSetting.shared.setKnockRoom(knock as! Bool)
                    return (knock as! Bool)
                }
            }
        }
        EnxSetting.shared.setKnockRoom(false)
        return false
    }
    func removeLobby(){
        if(lobbyView != nil){
            lobbyView.removeFromSuperview()
        }
    }
    //floorBtn
    func floorRequestOpt(){
        if(!getUserRole() && roomMode != "group"){
            floorBtn.frame = CGRect(x: 10, y: 5, width: 40, height: 40)
            localPlayer.addSubview(floorBtn)
            localPlayer.bringSubviewToFront(floorBtn)
            floorBtn.addTarget(self, action: #selector(requestFloor), for: .touchDown)
        }
    }
    @objc func requestFloor() {
        guard self.room != nil else { return }
        currentFloorStatus == "noRequest" ? self.room.requestFloor() : currentFloorStatus == "accepted" ?  self.room.finishFloor() : self.room.cancelFloor()
    }
}
//MARK: - Conformation Screen Events
extension EnxVideoViewClass : EnxConfirmationOption{
    func selectedOption(_ audio: Bool, video: Bool, AudioOnly: Bool) {
        confirmationView.removeFromSuperview()
        isAudioMuted = !audio
        isVideoMuted = !video
        isAudioOnly = AudioOnly
        joinRoom()
    }
}
//MARK: - Video Events
extension EnxVideoViewClass : EnxRoomDelegate,EnxStreamDelegate{
    ///Room Connected
    public func room(_ room: EnxRoom?, didConnect roomMetadata: [AnyHashable : Any]?) {
        if let timeFlag = UserDefaults.standard.object(forKey: "connectionTime"){
            if(timeFlag as! Bool == true){
                showTimer()
            }
        }
        removeLobby()
        let totalStream  : [Any] = roomMetadata!["streams"] as! [Any]
        totalSubscriberInRoom = totalStream.count
        self.room = room!
        if(localStream != nil){
            self.room.publish(localStream)
            localStream.attachRenderer(localPlayer)
        }
        loader.changeLoderMessage(message: "Preparing.....")
        let roomInfo = roomMetadata!["room"] as! [String : Any]
        let settingDet = roomInfo["settings"] as! [String : Any]
        roomMode = (settingDet["mode"] as! String)
        print("room MEta Data \(settingDet["mode"] as! String)")
        addBottomOption()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            bottomView.muteVideo(flag: isAudioOnly)
        }
        guard roomMetadata?["userList"] as? [Any] != nil else{
            return
        }
        parseEarlyJoinParticipant(roomMetadata?["userList"] as! [Any])
        parseTheRequestList(roomMetadata!["approvedHands"] as! [Any],isApproved: true)
        parseTheRequestList(roomMetadata!["raisedHands"] as! [Any],isApproved: false)
        parseTheAwaitedUserList(roomMetadata!["awaitedParticipants"] as! [Any])
        //update the setting flag
        EnxSetting.shared.connectionEstablishSuccess(true)
        EnxSetting.shared.updateRoomMode(withMode: roomMode)
        EnxSetting.shared.setRoom(self.room)
        EnxSetting.shared.updateUserRole(withRole: getUserRole())
        EnxSetting.shared.setClientId((self.room.clientId! as String))
        loader.createProgressBar(totalSubscriberInRoom)
        floorRequestOpt()
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
    }
    /// Remote stream added , now user need to subscribe same stream
    public func room(_ room: EnxRoom?, didAddedStream stream: EnxStream?) {
        guard self.room != nil else {return}
        self.room.subscribe(stream!)
    }
    /// self stream has published success
    public func room(_ room: EnxRoom?, didPublishStream stream: EnxStream?) {
        loader.updateProgressView()
    }
    /// All available remote stream has subscribe Success
    public func room(_ room: EnxRoom?, didSubscribeStream stream: EnxStream?) {
        //print(stream?.streamId as Any)
        loader.updateProgressView()
    }
    /// Any other user has join after me join
    public func room(_ room: EnxRoom?, userDidJoined Data: [Any]?) {
        if let userFlag = UserDefaults.standard.object(forKey: "participantJoin"){
            if(userFlag as! Bool == true){
                if let bundle = EnxSetting.shared.getPath(){
                    playSound(bundle.path(forResource:"new_user_enter", ofType: "caf")!)
                }
            }
        }
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
        NotificationCenter.default.post(name: Notification.Name(customeNotification.UserConnected.rawValue), object: partList, userInfo: nil)
        EnxSetting.shared.setParticipantList(participantList)
        //awaitedUser list update
        removeUserFromWaitingList(partList.clientId)
    }
    /// Any remote user got disconnected
    public func room(_ room: EnxRoom?, userDidDisconnected Data: [Any]?) {
        //To Do
        if let userFlag = UserDefaults.standard.object(forKey: "participantLeft"){
            if(userFlag as! Bool == true){
                if let bundle = EnxSetting.shared.getPath(){
                    playSound(bundle.path(forResource:"user_exit", ofType: "caf")!)
                }
            }
        }
        guard Data != nil && Data!.count > 0 else{
            return
        }
        let particData = Data![0] as! [String : Any]
        for (index,partList) in participantList.enumerated(){
            if(partList.clientId == (particData["clientId"] as! String)){
                participantList.remove(at: index)
                NotificationCenter.default.post(name: Notification.Name(customeNotification.UserDisconnected.rawValue), object: partList, userInfo: nil)
                break
            }
        }
        if(roomMode != "group"){
            removeReqiestList(particData["clientId"] as! String)
        }
        EnxSetting.shared.setParticipantList(participantList)
        //awaitedUser list update
        removeUserFromWaitingList((particData["clientId"] as! String))
    }
    /// Active talker list
    public func room(_ room: EnxRoom?, didActiveTalkerList Data: [Any]?) {

    }
    public func room(_ room: EnxRoom?, didActiveTalkerView view: UIView?) {
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
        tempVideoPlayerView = view
        loader.removeLoader()
    }
    //MARK: - Lecture Mode Delegates
    /// Delegates for Moderator
    public func didFloorRequestReceived(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        let requestFloorData = EnxRequestModel(clientID: (tempDict["clientId"] as! String), name: (tempDict["name"] as! String), status: "not accepted")
        getRequestsList([requestFloorData])
        
       //to Do
    }
    /// This delegate method will notify to all available modiatore, Once any participent has finished there floor request
    public func didFinishedFloorRequest(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        updateRequest((tempDict["clientId"] as! String), status: "finished")
    }
    /// This delegate method will notify to all available modiatore, Once any participent has cancled there floor request
    public func didCancelledFloorRequest(_ Data: [Any]?) {
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0  else {
            return
        }
        updateRequest((tempDict["clientId"] as! String), status: "cancel")
    }
    ///This delegate invoke when Moderator accepts the floor request.
    public func didGrantedFloorRequest(_ Data: [Any]?) {
        //to Do
        guard let tempDict = Data?[0] as? [String : Any], Data!.count>0 else {
            return
        }
        if (getUserRole()){
            updateRequest((tempDict["clientId"] as! String), status: "approved")
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
                    NotificationCenter.default.post(name: Notification.Name(customeNotification.UserUpdate.rawValue), object: iten, userInfo: nil)
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
                    NotificationCenter.default.post(name: Notification.Name(customeNotification.UserUpdate.rawValue), object: iten, userInfo: nil)
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
                EnxSetting.shared.updateMenuOptions(true, eventType: .recording)
            }
            recordingUi(true)
            if let userFlag = UserDefaults.standard.object(forKey: "startRec"){
                if(userFlag as! Bool == true){
                    if let bundle = EnxSetting.shared.getPath(){
                        playSound(bundle.path(forResource:"recording_start", ofType: "caf")!)
                    }
                }
            }
        }
    }
    public func roomRecordOff(_ Data: [Any]?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            guard self.bottomView != nil else{
                return
            }
            if(getUserRole()){
                EnxSetting.shared.updateMenuOptions(false, eventType: .recording)
            }
            recordingUi(false)
            if let userFlag = UserDefaults.standard.object(forKey: "stopRec"){
                if(userFlag as! Bool == true){
                    if let bundle = EnxSetting.shared.getPath(){
                        playSound(bundle.path(forResource:"recording_stop", ofType: "caf")!)
                    }
                }
            }
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
    public func room(_ room: EnxRoom, didMessageReceived data: [Any]?) {
        if let userFlag = UserDefaults.standard.object(forKey: "chatAudio"){
            if(userFlag as! Bool == true){
                if let bundle = EnxSetting.shared.getPath(){
                    playSound(bundle.path(forResource:"incoming_chat_message", ofType: "caf")!)
                }
            }
        }
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
    public func room(_ room: EnxRoom, didUserDataReceived data: [Any]?) {
        if let responseData = data{
            let iteams = responseData[0] as! [String : Any]
            if let message = iteams["message"] as? [String : Any]{
                if let type = message["type"]{
                    if (type as! String).caseInsensitiveCompare("message") == .orderedSame{
                        if(iteams["broadcast"] as! Bool) == true{
                            guard enxChatView != nil else{
                                return
                            }
                            enxChatView.updateTypingIndicator((message["typing"] as! Bool), name: (iteams["sender"] as! String))
                        }else{
                            if getWhichChatRoom().caseInsensitiveCompare((iteams["senderId"] as! String)) == .orderedSame{
                                guard enxChatView != nil else{
                                    return
                                }
                                enxChatView.updateTypingIndicator((message["typing"] as! Bool), name: (iteams["sender"] as! String))

                            }
                        }
                        return
                    }
                }
            }
            delegate?.didUserDataReceived?(responseData[0] as! [String : Any])
        }
    }
    public func room(_ room: EnxRoom?, didSetTalkerCount Data: [Any]?) {
        //Taker callback
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
                        EnxSetting.shared.updateMenuOptions(true, eventType: .muteRoom)
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
                        EnxSetting.shared.updateMenuOptions(false, eventType: .muteRoom)
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
        EnxToastView.showInParent(parentView: self, withText: "The host has muted all participants", forDuration: 1.0)
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
        removeLobby()
    }
    //MARK: - Share APis
    //Start Screen Share ACK
    public func room(_ room: EnxRoom?, didStartScreenShareACK Data: [Any]?) {
        //to Do
    }
    //Stop Screen Share ACK
    public func room(_ room: EnxRoom?, didStoppedScreenShareACK Data: [Any]?) {
        //to Do
    }
    //Start Screen Share Notification
    public func room(_ room: EnxRoom?, didScreenShareStarted stream: EnxStream?) {
        addShareUI(stream!, isStarted: true)
    }
    //Stop Screen Share Notification
    public func room(_ room: EnxRoom?, didScreenShareStopped stream: EnxStream?) {
        addShareUI(stream!, isStarted: false)
    }
    //whiteboard  Start ACK
    public func room(_ room: EnxRoom?, didStartCanvasACK Data: [Any]?) {
        //to Do
    }
    //whiteboard  Stop ACK
    public func room(_ room: EnxRoom?, didStoppedCanvasACK Data: [Any]?) {
        //to Do
    }
    //whiteboard started notification
    public func room(_ room: EnxRoom?, didCanvasStarted stream: EnxStream?) {
        addShareUI(stream!, isStarted: true)
    }
    //whiteboard Stop notification
    public func room(_ room: EnxRoom?, didCanvasStopped stream: EnxStream?) {
        addShareUI(stream!, isStarted: false)
    }
    //Annotation Start ACK
    public func room(_ room: EnxRoom?, didStartAnnotationACK Data: [Any]?) {
        EnxSetting.shared.updateMenuOptions(true, eventType: .annotation)
        EnxToastView.showInParent(parentView: self, withText:"Annotation has been stared", forDuration: 1.0)
        createToolBar(true)
        if let playe = tempAnnotedStream.enxPlayerView{
            replacAtView(false, With: playe)
        }
    }
    //Annotation Stop ACK
    public func room(_ room: EnxRoom?, didStoppedAnnotationACK Data: [Any]?) {
        EnxSetting.shared.updateMenuOptions(false, eventType: .annotation)
        createToolBar(false)
        guard self.room != nil else { return }
        if let playe = tempAnnotedStream.enxPlayerView{
            replacAtView(true, With: playe)
        }
        self.room.forceUpdateATList()
    }
    //Annotation Start Notification
    public func room(_ room: EnxRoom?, didAnnotationStarted stream: EnxStream?) {
        addShareUI(stream!, isStarted: true)
    }
    //Annotation Stop Notification
    public func room(_ room: EnxRoom?, didAnnotationStopped stream: EnxStream?) {
        addShareUI(stream!, isStarted: false)
    }
    //MARK: - File shared
    public func room(_ room: EnxRoom, didInitFileUpload data: [Any]?) {
        let uploadInfo = data![0] as! [String : Any]
        print("file data : \n \(uploadInfo)");
        let fileInfo = EnxSharedFileModel()
        fileInfo.text = (uploadInfo["name"] as! String)
        fileInfo.size = (uploadInfo["size"] as! Int)
        fileInfo.fileType = (uploadInfo["type"] as! String)
        fileInfo.upJobId = (uploadInfo["upJobId"] as! Int)
        fileInfo.username = "Me:"
        fileInfo.messageType = .send
        fileInfo.date = Date()
        fileInfo.fileStatus = "Uploading..."
        if((uploadInfo["broadcast"] as! Bool) == true){
            EnxSetting.shared.saveGroupFileshare(fileInfo)
            if(getWhichChatRoom() == "groupchat"){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.updateChatMessage(fileInfo)
            }
        }
        else{
            fileInfo.receipientsId = getWhichChatRoom()
            EnxSetting.shared.savePrivateFileShare(fileInfo)
            if(getWhichChatRoom() == fileInfo.receipientsId!){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.updateChatMessage(fileInfo)
            }
        }
    }
    public func room(_ room: EnxRoom, didFileUploaded data: [Any]?) {
        let uploadInfo = data![0] as! [String : Any]
        print("file data : \n \(uploadInfo)");
        let fileInfo = EnxSharedFileModel()
        fileInfo.text = (uploadInfo["name"] as! String)
        fileInfo.size = (uploadInfo["size"] as! Int)
        fileInfo.upJobId = (uploadInfo["upJobId"] as! Int)
        fileInfo.username = "Me:"
        fileInfo.messageType = .send
        fileInfo.date = Date()
        fileInfo.createdAt = (uploadInfo["createdAt"] as! Int)
        fileInfo.dlimit = (uploadInfo["dlimit"] as! Int)
        fileInfo.expiresAt = (uploadInfo["expiresAt"] as! Int)
        fileInfo.speed = (uploadInfo["speed"] as! Double)
        fileInfo.time = (uploadInfo["time"] as! Int)
        fileInfo.timeLimit = (uploadInfo["timeLimit"] as! Int)
        fileInfo.fileStatus = "Uploaded"
        if((uploadInfo["broadcast"] as! Bool) == true){
            EnxSetting.shared.updateGroupFileShare(fileInfo)
            if(getWhichChatRoom() == "groupchat"){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.modifyFilesEntry(fileInfo)
            }
        }
        else{
            fileInfo.receipientsId = getWhichChatRoom()
            EnxSetting.shared.updatePrivateFileShare(fileInfo)
                guard enxChatView != nil else{
                    return
                }
                enxChatView.modifyFilesEntry(fileInfo)
        }
    }
    public func room(_ room: EnxRoom, didFileUploadFailed data: [Any]?) {
        let uploadInfo = data![0] as! [String : Any]
        print("file data : \n \(uploadInfo)");
    }
    public func room(_ room: EnxRoom, didFileUploadStarted data: [Any]?) {
        let uploadInfo = data![0] as! [String : Any]
        print("file data : \n \(uploadInfo)");
    }
    public func room(_ room: EnxRoom, didFileUploadCancelled data: [Any]?) {
        //Will handle this in feature
    }
    public func room(_ room: EnxRoom, didFileAvailable data: [Any]?) {
        let uploadInfo = data![0] as! [String : Any]
        print("file data : \n \(uploadInfo)");
        let fileInfo = EnxSharedFileModel()
        fileInfo.text = (uploadInfo["name"] as! String)
        fileInfo.size = (uploadInfo["size"] as! Int)
        fileInfo.username = (uploadInfo["sender"] as! String)
        fileInfo.messageType = .receive
        fileInfo.date = Date()
        fileInfo.createdAt = (uploadInfo["createdAt"] as! Int)
        fileInfo.dlimit = (uploadInfo["dlimit"] as! Int)
        fileInfo.expiresAt = (uploadInfo["expiresAt"] as! Int)
        fileInfo.speed = (uploadInfo["speed"] as! Double)
        fileInfo.time = (uploadInfo["time"] as! Int)
        fileInfo.timeLimit = (uploadInfo["timeLimit"] as! Int)
        fileInfo.index = (uploadInfo["index"] as! Int)
        fileInfo.receipientsId = (uploadInfo["senderId"] as! String)
        fileInfo.fileStatus = "[Swip to Download]"
        if((uploadInfo["broadcast"] as! Bool) == true){
            EnxSetting.shared.saveGroupFileshare(fileInfo)
            if(getWhichChatRoom() == "groupchat"){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.updateChatMessage(fileInfo)
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
            EnxSetting.shared.savePrivateFileShare(fileInfo)
            if(getWhichChatRoom() == fileInfo.receipientsId!){
                guard enxChatView != nil else{
                    return
                }
                enxChatView.updateChatMessage(fileInfo)
            }
            else{
                updateUserListforChatdata(fileInfo.receipientsId, isView: false)
            }
        }
    }
    public func room(_ room: EnxRoom, didInitFileDownload data: [Any]?) {
        guard enxChatView != nil else{
            return
        }
        enxChatView.fileDownloaded(false,downloadMessage: nil)
    }
    public func room(_ room: EnxRoom, didFileDownloaded data: String?) {
        guard enxChatView != nil else{
            return
        }
        enxChatView.fileDownloaded(true, downloadMessage: data)
        
    }
    public func room(_ room: EnxRoom, didFileDownloadFailed data: [Any]?) {
        guard enxChatView != nil else{
            return
        }
        enxChatView.fileDownloaded(true, downloadMessage: "File Downlod failed")
    }
    public func room(_ room: EnxRoom, didFileDownloadCancelled data: [Any]?) {
        //Will handle this in feature
    }
    public func room(_ room: EnxRoom?, didConferencessExtended data: [Any]?) {
        if let confAudio = UserDefaults.standard.object(forKey: "sessionExp"){
            if(confAudio as! Bool == true){
                if let bundle = EnxSetting.shared.getPath(){
                    playSound(bundle.path(forResource:"session_expiry", ofType: "caf")!)
                }
            }
        }
    }
    public func room(_ room: EnxRoom?, didConferenceRemainingDuration data: [Any]?) {
        //to do
    }
   
    //MARK: - Room Awaited
    public func room(_ room: EnxRoom?, diduserAwaited data: [Any]?) {
        //Handle awaited user list
        if let awaitedDict = data![0] as? [String: Any] {
            let awaitedUser = EnxRequestModel(clientID: (awaitedDict["clientId"] as! String), name: (awaitedDict["name"] as! String), status: "not accepted")
            if requestiesList.keys.contains(where: { $0 == "Awaited User Request"}){
                var awaitedReq = requestiesList["Awaited User Request"]!
                    awaitedReq.append(awaitedUser)
                requestiesList.updateValue(awaitedReq, forKey: "Awaited User Request")
            } else {
                requestiesList["Awaited User Request"] = [awaitedUser]
            }
            updateOptionList()
            guard enxReqPopOver != nil else{
                    return
                }
            enxReqPopOver.getRequestsList([awaitedUser] , key: "Awaited User Request")
        }
       
        //send Notification
    }
    public func room(_ room: EnxRoom?, didRoomAwated reason: [Any]?) {
        self.room = room
        //Handle room awaited UI
        lobbyView = EnxLobbyView((room?.clientName)! as String)
        self.addSubview(lobbyView)
        lobbyView.delegate = self
        lobbyView.frame = self.bounds
        lobbyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    //MARK: - Switch Role
    
    public func room(_ room: EnxRoom?, didSwitchUserRole data: [Any]?) {
        //
    }
    public func room(_ room: EnxRoom?, didUserRoleChanged data: [Any]?) {
        if(bottomView.bounds.height > 85){
            updateButtomOptOnTap()
        }
        EnxSetting.shared.updateUserRole(withRole: getUserRole())
        let list = data![0] as! [String : Any]
        NotificationCenter.default.post(name: Notification.Name(customeNotification.RoleChange.rawValue), object: room?.userRole, userInfo: ["role" : room!.userRole , "clientId" : list["moderator"]!])
    }
    //MARK: - Switch Room
    public func room(_ room: EnxRoom?, didRoomModeSwitched data: [Any]?) {
        if let response = data![0] as? [String : Any]{
            print("response \(response)")
            EnxToastView.showInParent(parentView: self, withText: (response["msg"] as! String), forDuration: 0.8)
            roomMode = (response["mode"] as! String)
            EnxSetting.shared.updateRoomMode(withMode: roomMode)
            floorRequestOpt()
        }
    }
    //MARK: - Share Premisses
    public func room(_ room: EnxRoom?, didSharePermissionDeny data: [Any]) {
        if getUserRole(){
            let responseVal = data[0] as! [String : Any]
            if let pubType = responseVal["params"] as? [String : Any]{
                if (pubType["pubType"] as! String).caseInsensitiveCompare("screen") == .orderedSame{
                    removeValueForShareRequest((pubType["clientId"] as! String))
                }else{
                    
                    removeValueForCanvasRequest((pubType["clientId"] as! String))
                }
            }
        }
    }
    public func room(_ room: EnxRoom?, didSharePermissionsModeChanged data:[Any]) {
        if getUserRole(){
            EnxToastView.showInParent(parentView: self, withText: "Screen share permissions have been updated", forDuration: 0.8)
        }
        else{
            EnxToastView.showInParent(parentView: self, withText: "Screen share permissions have been updated by Moderator", forDuration: 0.8)
        }
    }
    public func room(_ room: EnxRoom?, didSharePermissionRequested  data:[Any]) {
        if getUserRole(){
            let responseVal = data[0] as! [String : Any]
            if let pubType = responseVal["params"] as? [String : Any]{
                if (pubType["pubType"] as! String).caseInsensitiveCompare("screen") == .orderedSame{
                    let requestFloorData = EnxRequestModel(clientID: (pubType["clientId"] as! String), name: getName((pubType["clientId"] as! String)), status: "Request")
                    parseSharePremissedUpdate(requestFloorData, status: "ScreenRequest")
                }else{
                    let requestFloorData = EnxRequestModel(clientID: (pubType["clientId"] as! String), name: getName((pubType["clientId"] as! String)), status: "Request")
                    parseSharePremissedUpdate(requestFloorData, status: "CanvasRequest")
                }
            }
        }
    }
    public func room(_ room: EnxRoom?, didSharePermissionReleased  data:[Any]) {
        if getUserRole(){
            let responseVal = data[0] as! [String : Any]
            if let pubType = responseVal["params"] as? [String : Any]{
                if (pubType["pubType"] as! String).caseInsensitiveCompare("screen") == .orderedSame{
                    removeValueForShareRequest((pubType["clientId"] as! String))
                }else{
                    
                    removeValueForCanvasRequest((pubType["clientId"] as! String))
                }
            }
        }
    }
    public func room(_ room: EnxRoom?, didSharePermissionCancled  data:[Any]) {
        if getUserRole(){
            let responseVal = data[0] as! [String : Any]
            if let pubType = responseVal["params"] as? [String : Any]{
                if (pubType["pubType"] as! String).caseInsensitiveCompare("screen") == .orderedSame{
                    removeValueForShareRequest((pubType["clientId"] as! String))
                }else{
                    
                    removeValueForCanvasRequest((pubType["clientId"] as! String))
                }
            }
        }
    }
    public func room(_ room: EnxRoom?, didSharePermissionGranted  data:[Any]) {
        if getUserRole(){
            if getUserRole(){
                let responseVal = data[0] as! [String : Any]
                if let pubType = responseVal["params"] as? [String : Any]{
                    if (pubType["pubType"] as! String).caseInsensitiveCompare("screen") == .orderedSame{
                        updateValueForShareRequest((pubType["clientId"] as! String))
                    }else{
                        
                        updateValueForCanvasRequest((pubType["clientId"] as! String))
                    }
                }
            }
        }
        else{
            //handel participant
        }
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
        var rect = self.bounds;
        rect.origin.x = rect.width
        for items in mList{
            let audioModel = EnxAudioMediaModel()
            audioModel.mediaName = (items as! String)
            self.room.getSelectedDevice() == (items as! String) ? (audioModel.isSelected = true) : (audioModel.isSelected = false)
            mediaList.append(audioModel)
        }
        enxAudioMediaView = EnxAudioMediaListView(audioMediaList: mediaList,delegate: self)
        enxAudioMediaView.frame = rect
        self.addSubview(enxAudioMediaView)
        self.bringSubviewToFront(enxAudioMediaView)
        UIView.animate(withDuration: 1.0, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0, options: .layoutSubviews, animations: { [self] in
            let moveLeft = CGAffineTransform(translationX: -self.bounds.width, y: 0.0)
            enxAudioMediaView.transform = moveLeft
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                    self.enxAudioMediaView.updateListViewAlpha()
                }
            }, completion: {_ in
                self.enxAudioMediaView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            })
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
            self.enxChatView.isFileShareSubscriptionAvailable(self.isFileSubscriptionAvailable())
            self.messageCount = 0
            guard self.bottomView != nil else{
                return
            }
            self.bottomView.updategroupChatCount(self.messageCount)
        })
        delegate?.didPageSlide?(.EnxChat, isShow: true)
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
        var disconnectOpt = false
        getUserRole() ? (disconnectOpt = true) : (disconnectOpt = getUserChooise())
        disconnectOpt ? showDisconnectOpt() : disconnectRoom()
    }
    private func getUserChooise() -> Bool{
        if let userFlag = UserDefaults.standard.object(forKey: "askToConf"){
            return (userFlag as! Bool)
        }
        return false
    }
    func showDisconnectOpt(){
        let alertController  = UIAlertController(title: "Are you sure?", message: getUserRole() ?"  \n " : "", preferredStyle:.alert)
        if(getUserRole()){
            alertController.view .addSubview(getModeOption())
        }
        let alertAction = UIAlertAction(title: "Ok", style: .default , handler: { [self]_ in
            guard self.room != nil else { return }
            optnBtn.isSelected ? room.destroy() : disconnectRoom()
        })
        alertController.addAction(alertAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .default)
        alertController.addAction(cancelAction)
        if let topViewController  = getTopMostViewController(){
            topViewController.present(alertController, animated: true)
        }
    }
    func getTopMostViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
        return topController
        }
        return nil
    }
    func disconnectRoom(){
        guard self.room != nil else { return }
        room.disconnect()
    }
    func clickToChangeRole(_ clientID : String){
        guard self.room != nil else { return }
        room.switchUserRole(clientID)
    }
    func getModeOption() -> UIView {
        let view = UIView(frame: CGRect(x: 20, y: 45, width: 200, height: 40))
        imageIcn.frame = CGRect(x: 20, y: 5, width: 30, height: 30)
        view.addSubview(imageIcn)
        let messageLBL = UILabel(frame: CGRect(x: 55, y: 10, width: 120, height: 20))
        messageLBL.text = "End meeting on exit"
        messageLBL.font = UIFont.systemFont(ofSize: 14)
        messageLBL.sizeToFit()
        view.addSubview(messageLBL)
        optnBtn.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        optnBtn.addTarget(self, action: #selector(clickToSelectOpt), for: .touchDown)
        view.addSubview(optnBtn)
        return view
    }
    @objc func clickToSelectOpt(){
        optnBtn.isSelected = !optnBtn.isSelected
        if let bundle = EnxSetting.shared.getPath(){
            optnBtn.isSelected ? (imageIcn.image = UIImage(contentsOfFile: bundle.path(forResource: "userCheck", ofType: "png")!)) : (imageIcn.image = UIImage(contentsOfFile: bundle.path(forResource: "userUnCheck", ofType: "png")!))
        }
    }
    func showMoreView(){
        navigateToShowView(enxMenuListView)
        enxMenuListView.loadView(listOfOptions: EnxSetting.shared.getMenuOpt(isKnock: checkIsRoomKnockEnable()), delegate: self)
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
            self.enxChatView.isFileShareSubscriptionAvailable(self.isFileSubscriptionAvailable())
            self.updateUserListforChatdata(clientID, isView: true)
        })
        delegate?.didPageSlide?(.EnxChat, isShow: true)
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
                EnxSetting.shared.updateMenuOptions(true, eventType: .switchAT)
            }
            else{
                self.room.switch(atView: "gallery")
                EnxSetting.shared.updateMenuOptions(false, eventType: .switchAT)
            }
    }
    //Navigate Back
    func tapOnMenuViewToNavigateBack(){
        navigateToHideViewBAck(enxMenuListView)
    }
    //Annotation
    func annotation(_ isStart: Bool) {
        guard self.room != nil else {return}
        if(isStart){
            self.room.stopAnnotation()
            self.room.setActiveTalkerDelegate(nil)
        }
        else{
            self.room.setActiveTalkerDelegate(self)
            EnxToastView.showInParent(parentView: self, withText:"Please swap on Player, On which you wanted to start annotation", forDuration: 1.0)
        }
    }
    //POlling
    func pollingEvents(_ isStart : Bool){
        delegate?.didPageSlide?(.EnxPolling, isShow: true)
    }
    //QNA
    func qnaEvents(_ isStart : Bool){
        delegate?.didPageSlide?(.EnxQnA, isShow: true)
    }
    func lobbyEvents(_ isStart : Bool){
        if !requestiesList.keys.contains(where: { $0 == "Awaited User Request"}){
            EnxToastView.showInParent(parentView: self, withText: "No Request Found", forDuration: 1.0)
            return
        }
        var rect = self.bounds;
        rect.origin.x = rect.width
        enxReqPopOver = EnxrequestPopOverView(requestDataList: requestiesList, delegate : self)
        enxReqPopOver.frame = rect
        self.addSubview(enxReqPopOver)
        self.bringSubviewToFront(enxReqPopOver)
        enxReqPopOver.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        UIView.animate(withDuration: 0.35, animations: { [self] in
            let moveLeft = CGAffineTransform(translationX: -self.bounds.width, y: 0.0)
            enxReqPopOver.transform = moveLeft
        },completion: nil)
    }
    func shareScreen(_ isStart : Bool){
        delegate?.didPageSlide?(.EnxScreenShare, isShow: true)
    }
    func showRequestList(_ isStart : Bool) {
        if !requestiesList.keys.contains(where: { $0 == "User Floor Request"}) && !requestiesList.keys.contains(where: { $0 == "User Canvas Request"}) && !requestiesList.keys.contains(where: { $0 == "User Share Request"}){
            EnxToastView.showInParent(parentView: self, withText: "No Request Found", forDuration: 1.0)
            return
        }
        var rect = self.bounds;
        rect.origin.x = rect.width
        enxReqPopOver = EnxrequestPopOverView(requestDataList: requestiesList, delegate : self)
        enxReqPopOver.frame = rect
        enxReqPopOver.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.addSubview(enxReqPopOver)
        self.bringSubviewToFront(enxReqPopOver)
        UIView.animate(withDuration: 0.35, animations: { [self] in
            let moveLeft = CGAffineTransform(translationX: -self.bounds.width, y: 0.0)
            enxReqPopOver.transform = moveLeft
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [self] in
                self.enxReqPopOver.updateAlpha()
            }
            },completion:nil)
    }
    func showRoomSetting(_ isStart : Bool){
        //Need to handle
        navigateToShowView(enxRoomSettingView)
        enxRoomSettingView.loadView(delegate: self , shareData: self.room.getSharePermissions())
    }
}
//MARK: - Request PopoverDelegate
//Request PopoverDelegate
extension EnxVideoViewClass : EnxRequestPopOverDelegates{
    func denyAwaitedUser(_ clientId : String){
        guard room != nil else{
            return
        }
        room.denyAwaitedUser(clientId)
    }
    func grantAwaitedUser(_ clientId : String){
        guard room != nil else{
            return
        }
        room.approveAwaitedUser(clientId)
    }
    
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
        UIView.animate(withDuration: 0.35, animations: { [self] in
            let moveLeft = CGAffineTransform(translationX: 0, y: 0.0)
            self.enxReqPopOver.transform = moveLeft
        },completion: {_ in
            self.enxReqPopOver.removeFromSuperview()
        })
    }
    func shareRequestAccept(_ clientId : String){
        guard room != nil else{
            return
        }
        self.room.grantSharePermission(Screen, requestyId: clientId)
    }
    func shareRequestDeny(_ clientId : String){
        guard room != nil else{
            return
        }
        self.room.denySharePermission(Screen, requestyId: clientId)
    }
    func shareRequestRelease(_ clientId : String){
        guard room != nil else{
            return
        }
        self.room.releaseSharePermission(Screen, requestyId: clientId)
    }
    func canvasRequestAccept(_ clientId : String){
        guard room != nil else{
            return
        }
        self.room.grantSharePermission(Canvas, requestyId: clientId)
    }
    func canvasRequestDeny(_ clientId : String){
        guard room != nil else{
            return
        }
        self.room.denySharePermission(Canvas, requestyId: clientId)
    }
    func canvasRequestRelease(_ clientId : String){
        guard room != nil else{
            return
        }
        self.room.releaseSharePermission(Canvas, requestyId: clientId)
    }
}
//MARK: - ChatView delegate
//Request PopoverDelegate
extension EnxVideoViewClass : EnxChatViewDelegate{
    func sendFile(_ clientId: String) {
        guard self.room != nil else { return }
        if(clientId == "groupchat"){
            self.room.sendFiles(true, clientIds: [])
        }else{
            self.room.sendFiles(false, clientIds: [clientId])
        }
    }
    //DownloadFile
    func downloadFile(_ fileInfo : EnxSharedFileModel){
        guard self.room != nil else { return }
        let availableFiles = self.room.getAvailableFiles()
        if(availableFiles!.count > 0){
            for item in availableFiles! {
                let infoDetail = item as! [String : Any]
                if((infoDetail["index"] as! Int) == fileInfo.index){
                    self.room.downloadFile(infoDetail, autoSave: true)
                }
            }
        }
    }
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
        delegate?.didPageSlide?(.EnxChat, isShow: false)
    }
    func sendTypingIndicator(_ isgroup : Bool, isTyping : Bool, toreceverId: String){
        guard self.room != nil else { return }
        let messageData : [String : Any] = ["type":"message", "typing" : isTyping]
        isgroup ? (self.room.sendUserData(messageData, isBroadCast: true, recipientIDs: nil)) : (self.room.sendUserData(messageData, isBroadCast: false, recipientIDs: [toreceverId]))
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
//MARK: - ChatView delegate
//Request PopoverDelegate
extension EnxVideoViewClass : EnxTalkerStreamDelegate{
    public func didSelectedStream(atIndex stream: EnxStream) {
        guard self.room != nil else {return}
        tempAnnotedStream = stream
        self.room.startAnnotation(tempAnnotedStream)
    }
}

extension EnxVideoViewClass : UIGestureRecognizerDelegate{
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
//        if(touch.view!.isDescendant(of: optionImage) || touch.view!.isDescendant(of: arrowBtn) || touch.view!.isDescendant(of: bottomView)){
//            return false
//        }
        return true
    }
}
extension EnxVideoViewClass : userLobbyAction{
    func userDisconnected(){
        guard self.room != nil else {return}
        self.room.disconnect()
    }
}
//Room Setting page User events CallBack
extension EnxVideoViewClass : EnxRoomSeteingDelegate{
    func tapOnRoomSettingViewToNavigateBack(){
        navigateToHideViewBAck(enxRoomSettingView)
    }
    func switchRoom(_ isGroup : Bool){
        guard self.room != nil else {return}
        isGroup ? (room.switchMode("group")) : room.switchMode("lecture")
    }
    func applySharePrivacy(_ mode : EnxPubMode)
    {
        guard self.room != nil else {return}
        self.room.setSharePermissionMode(Screen, withmode: mode)
    }
    func applyCanvasPrivacy(_ mode : EnxPubMode){
        guard self.room != nil else {return}
        self.room.setSharePermissionMode(Canvas, withmode: mode)
    }
}
