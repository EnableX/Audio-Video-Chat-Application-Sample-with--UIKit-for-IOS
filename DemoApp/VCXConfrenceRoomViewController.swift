//
//  ViewController.swift
//  sampleiOS
//
//  Created by Jay Kumar on 28/11/18.
//  Copyright © 2018 Jay Kumar. All rights reserved.
//

import UIKit
import Enx_UIKit_iOS

class VCXConfrenceRoomViewController: UIViewController  {

    var roomInfo : VCXRoomInfoModel!
    var videoView : EnxVideoViewClass!
    
    
    @IBOutlet weak var shareBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.createToken()
        // Do any additional setup after loading the view, typically from a nib.
    }
    private func createToken(){
        guard VCXNetworkManager.isReachable() else {
            self.showAleartView(message:"Kindly check your Network Connection", andTitles: "OK")
            return
        }
        let inputParam : [String : String] = ["name" :roomInfo.participantName , "role" :  roomInfo.role ,"roomId" : roomInfo.room_id, "user_ref" : "2236"]
        VCXServicesClass.featchToken(requestParam: inputParam, completion:{tokenInfo  in
            DispatchQueue.main.async {
              //  Success Response from server
                if let token = tokenInfo.token {
                    self.videoView = EnxVideoViewClass(token: token, delegate: self, embedUrl: nil)
                    self.view.addSubview(self.videoView)
                    self.videoView.frame = self.view.bounds
                    self.videoView.autoresizingMask = [.flexibleHeight,.flexibleWidth]
                }
                //Handel if Room is full
                else if (tokenInfo.token == nil && tokenInfo.error == nil){
                    self.showAleartView(message:"Token Denied. Room is full.", andTitles: "OK")
                }
                //Handeling server error
                else{
                    print(tokenInfo.error)
                    self.showAleartView(message:tokenInfo.error, andTitles: "OK")
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
}
extension VCXConfrenceRoomViewController : EnxVideoStateDelegate{
    
    func disconnect(response: [Any]?) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func connectError(reason: [Any]?) {
        //error while connecting
    }
}
