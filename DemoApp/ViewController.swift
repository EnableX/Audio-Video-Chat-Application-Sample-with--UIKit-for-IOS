//
//  ViewController.swift
//  DemoApp
//
//  Created by jaykumar on 04/05/22.
//

import UIKit
import AVFoundation


class ViewController: UIViewController {
    
    @IBOutlet weak var roomNameTxt: UITextField!
    @IBOutlet weak var nameTxt: UITextField!
    @IBOutlet weak var joinBtn: UIButton!
    @IBOutlet weak var stackView: UIView!
    @IBOutlet weak var createRoom: UIButton!
    var isModerator : Bool! = true
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.getPrivacyAccess()
        self.prepareView()
        // Do any additional setup after loading the view.
    }
    private func getPrivacyAccess(){
        let vStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if(vStatus == AVAuthorizationStatus.notDetermined){
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
            })
        }
        let aStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if(aStatus == AVAuthorizationStatus.notDetermined){
            AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (granted: Bool) in
            })
        }
    }
    // MARK: - prepareView
    /**
     adjust mainView layer conrnerRadius
     adjust joinBtn layer conrnerRadius
     adjust createRoom layer conrnerRadius
     adjust topView layer conrnerRadius
     check its Room All ready Created or not
     **/
    private func prepareView(){
        stackView.layer.cornerRadius = 8.0
        joinBtn.layer.cornerRadius = 8.0
        createRoom.layer.cornerRadius = 8.0
    }
    // MARK: - Create Room
    /**
     Call to create Room
     Input parameter :- Any
     **/
    @IBAction func createRoomEvent(_ sender: Any) {
        guard VCXNetworkManager.isReachable() else {
            self.showAleartView(message:"Kindly check your Network Connection", andTitles: "OK")
            return
        }
        self.keyBoardDismiss()
        
        VCXServicesClass.createRoom(completion:{roomInfo  in
            DispatchQueue.main.async {
                //Success Response from server
                if roomInfo.room_id != nil{
                    self.roomNameTxt.text = roomInfo.room_id
                }
                //Handeling server giving no error but due to wrong PIN room not available
                else if roomInfo.isRoomFlag == false && roomInfo.error == nil {
                    self.showAleartView(message:"Unable to connect, Kindly try again", andTitles: "OK")
                }
                //Handeling server error
                else{
                    print(roomInfo.error)
                    self.showAleartView(message:roomInfo.error, andTitles: "OK")
                }
                
            }
        })
    }
    // MARK: - Join Button Event
    /**
     Validate  maindatory Filed should not empty
     Show Loader
     Call Rest Service to join Room with Required Information.
     **/
    @IBAction func clickToJoinRoom(_ sender: Any) {
        guard let nameStr = nameTxt.text?.trimmingCharacters(in: .whitespaces) ,!nameStr.isEmpty else{
            self.showAleartView(message: "Please enter name", andTitles: "OK")
            return}
        guard let roomNameStr = roomNameTxt.text?.trimmingCharacters(in: .whitespaces) , !roomNameStr.isEmpty else {
            self.showAleartView(message: "Please enter room Id", andTitles: "OK")
            return}
        guard VCXNetworkManager.isReachable() else {
            self.showAleartView(message:"Kindly check your Network Connection", andTitles: "OK")
            return
        }
        self.keyBoardDismiss()
        VCXServicesClass.fetchRoomInfoWithRoomId(roomId :roomNameStr ,completion:{roomModel  in
            DispatchQueue.main.async {
                //Success Response from server
                if roomModel.room_id != nil{
                    roomModel.role = "participant"
                    roomModel.participantName = nameStr
                    self.performSegue(withIdentifier: "ConferenceView", sender: roomModel)
                }
                //Handeling server giving no error but due to wrong PIN room not available
                else if roomModel.isRoomFlag == false && roomModel.error == nil {
                    self.showAleartView(message:"Room not found", andTitles: "OK")
                }
                    //Handeling server error
                else{
                    print(roomModel.error)
                    self.showAleartView(message:roomModel.error, andTitles: "OK")
                }
            }
        })
    }
    // MARK: - Show Alert
    /**
     Show Alert Based in requirement.
     Input parameter :- Message and Event name for Alert
     **/
    private func showAleartView(message : String, andTitles : String){
        let alert = UIAlertController(title: " ", message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: andTitles, style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    // MARK: - keyBoardDismiss
    /**
     Hide KeyBoard
     Input parameter :- Nil
     **/
    private func keyBoardDismiss(){
        nameTxt.resignFirstResponder()
        roomNameTxt.resignFirstResponder()
    }
    // MARK: - SegueEvent
    /**
     here getting refrence to next moving controll and passing requirade parameter
     Input parameter :- UIStoryboardSegue andAny
     Return parameter :- Nil
     **/
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            let confrenceVC = segue.destination as! VCXConfrenceRoomViewController
            confrenceVC.roomInfo = (sender as! VCXRoomInfoModel)
    
    }
}

// MARK: - Extension for View Property
extension UIView {
    func round(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 5, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        self.layer.mask = mask
    }
}

// MARK: - UItextField delegate methods
extension ViewController :  UITextFieldDelegate{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true;
    }
}

