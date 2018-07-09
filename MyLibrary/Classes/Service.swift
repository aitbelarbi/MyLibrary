//
//  Service.swift
//  MyLibrary
//
//  Created by Mohamed AITBELARBI on 06/07/2018.
//


import Foundation
import AVFoundation
import Alamofire
import AlamofireObjectMapper

public protocol ServiceDelegate {
    func playSound(data: Data, startListening: Bool)
    func showError()
    func serverRecordSuccess()
}

public class Service {
    static let INTEGRATION_BASE_URL = "https://hrp-gateway.int.inpoclab.com"
    static let PREPROD_BASE_URL = "https://hrp-gateway.preprod.inpoclab.com"
    static let PROD_BASE_URL = "https://hrp-gateway.inpoclab.com"
    
    private var baseUrl = INTEGRATION_BASE_URL
    static let shared = Service()
    var delegate: ServiceDelegate?
    var service: String?
    
    private var username: String = ""
    private var firstname: String = ""
    private var lastname: String = ""
    private var userId: String = ""
    
    func getResponse(url: URL) {
        var r  = URLRequest(url: URL(string: "\(baseUrl)/ms_chappie/inquiries")!)
        r.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        r.setValue(service, forHTTPHeaderField: "service")
        
        var data = Data()
        do { data = try Data(contentsOf: url) } catch {}
        let params = ["audio_format": "mp3"]
        r.httpBody = createBody(parameters: params,
                                boundary: boundary,
                                data: data,
                                mimeType: "audio/wav",
                                name: "audio_inquiry",
                                filename: "recording.wav")
        
        let task = URLSession.shared.dataTask(with: r, completionHandler: {data, response, error -> Void in
            if let error = error {
                self.delegate?.showError()
                return
            }
            if let soundData = data {
                var startListening = false
                if let headers = (response as? HTTPURLResponse)?.allHeaderFields {
                    self.service = headers["service"] as? String
                    if let listening = headers["follow_up"] {
                        startListening = (listening as! String).toBool()
                    }
                }
                self.delegate?.playSound(data: soundData, startListening: startListening)
            } else {
                self.delegate?.showError()
            }
        })
        task.resume()
    }
    
    func getUser(username: String? = "", success: @escaping ((_ users: [User]) -> Void), failed: @escaping (() -> Void)) {
        if username != "" {
            self.username = username!
        }
        let headers = [
            "filter" : "{\"where\": {\"username\": \"\(self.username)\"}}"
        ]
        Alamofire.request("\(baseUrl)/back_hrp/accounts",
            method: .get,
            parameters: nil,
            encoding: JSONEncoding.default,
            headers: headers)
            .responseArray(completionHandler: { (response: DataResponse<[User]>) in
                switch response.result
                {
                case .failure(_):
                    failed()
                case .success(let users):
                    if let id = users.first?.id {
                        self.userId = id
                    }
                    success(users)
                }
            })
    }
    
    func setEnrollUser(url: URL) {
        print("url : \(baseUrl)/users/\(username)/enrollments")
        
        var r  = URLRequest(url: URL(string: "\(baseUrl)/ms_chappie/users/\(username)/enrollments")!)
        r.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        do { data = try Data(contentsOf: url) } catch {}
        
        r.httpBody = createBody(parameters: [:],
                                boundary: boundary,
                                data: data,
                                mimeType: "audio/wav",
                                name: "audio_enrollment",
                                filename: "recording.wav")
        
        let task = URLSession.shared.dataTask(with: r, completionHandler: {data, response, error -> Void in
            if let error = error {
                self.delegate?.showError()
                return
            }
            if let _ = data {
                if (response as! HTTPURLResponse).statusCode == 201 {
                    self.delegate?.serverRecordSuccess()
                }else {
                    self.delegate?.showError()
                }
            }
        })
        task.resume()
    }
    
    func createEnrollUser(username: String, firstname: String, lastname: String, success: @escaping ((_ showAlert: Bool) -> Void), failed: @escaping (() -> Void)) {
        
        self.firstname = firstname
        self.lastname = lastname
        self.username = username
        
        getUser(success: { (users) in
            if users.count == 0 {
                let parameters: Parameters = [
                    "username": username,
                    "firstname": firstname,
                    "lastname": lastname,
                    "linkServices": ["voiceit"]
                ]
                let headers: HTTPHeaders = [
                    "Content-Type": "application/json"
                ]
                Alamofire.request("\(self.baseUrl)/back_hrp/accounts",
                    method: .post,
                    parameters: parameters,
                    encoding: JSONEncoding.default,
                    headers: headers)
                    .responseJSON(completionHandler: { (response) in
                        switch response.result
                        {
                        case .failure(_):
                            failed()
                        case .success(_):
                            success(false)
                        }
                    })
            } else if users.first?.voiceIt != nil {
                if let id = users.first?.id {
                    self.userId = id
                }
                success(true)
            } else if users.first?.voiceIt == nil {
                if let id = users.first?.id {
                    self.userId = id
                    self.linkNewVoiceItAccount(success: success, failed: failed)
                } else {
                    failed()
                }
            }
        }, failed: {
            failed()
        })
    }
    
    func deleteEnrollUser(userId: String? = "", success: @escaping (() -> Void), failed: @escaping (() -> Void)) {
        
        if userId != "" {
            self.userId = userId!
        }
        
        Alamofire.request("\(self.baseUrl)/back_hrp/accounts/\(self.userId)/voiceit",
            method: .delete,
            parameters: nil,
            encoding: JSONEncoding.default,
            headers: nil)
            .responseObject(completionHandler: { (response: DataResponse<User>) in
                switch response.result
                {
                case .failure(_):
                    failed()
                case .success(let user):
                    if let id = user.id {
                        self.userId = id
                    }
                    if response.response?.statusCode == 200 {
                        success()
                    } else {
                        failed()
                    }
                }
            })
    }
    
    func linkNewVoiceItAccount(success: @escaping ((_ showAlert: Bool) -> Void), failed: @escaping (() -> Void)) {
        let headers: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        let parameters: Parameters = [
            "linkServices": ["voiceit"]
        ]
        
        Alamofire.request("\(baseUrl)/back_hrp/accounts/\(userId)",
            method: .patch,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers)
            .responseJSON(completionHandler: { (response) in
                switch response.result
                {
                case .failure(_):
                    failed()
                case .success(_):
                    if response.response?.statusCode == 200 {
                        success(false)
                    }
                }
            })
    }
    
    private func createBody(parameters: [String: String],
                            boundary: String,
                            data: Data,
                            mimeType: String,
                            name: String,
                            filename: String) -> Data {
        let body = NSMutableData()
        
        let boundaryPrefix = "--\(boundary)\r\n"
        
        for (key, value) in parameters {
            body.appendString(boundaryPrefix)
            body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendString("\(value)\r\n")
        }
        
        body.appendString(boundaryPrefix)
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
        body.appendString("--".appending(boundary.appending("--")))
        
        return body as Data
    }
    
    func identify(url: URL, appId: String, success: @escaping ((_ data: Data) -> Void), failed: @escaping (() -> Void)) {
        var r  = URLRequest(url: URL(string: "\(baseUrl)/users/identity")!)
        r.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        r.setValue(appId, forHTTPHeaderField: "app_id")
        
        var data = Data()
        do { data = try Data(contentsOf: url) } catch {}
        let params = ["audio_format": "mp3",
                      "sample_rate": "48000"]
        r.httpBody = createBody(parameters: params,
                                boundary: boundary,
                                data: data,
                                mimeType: "audio/wav",
                                name: "audio_inquiry",
                                filename: "recording.wav")
        
        let task = URLSession.shared.dataTask(with: r, completionHandler: {data, response, error -> Void in
            if let _ = error {
                failed()
                return
            }
            if let responseData = data {
                success(responseData)
            } else {
                failed()
            }
        })
        task.resume()
    }
    
    func textToSpeech(text: String, success: @escaping ((_ data: Data) -> Void), failed: @escaping (() -> Void)) {
        let parameters: Parameters = [
            "text": text
        ]
        let headers = [
            "Content-Type": "application/form-data"
        ]
        Alamofire.request("\(baseUrl)/tts",
            method: .post,
            parameters: parameters,
            encoding: URLEncoding.default,
            headers: headers)
            .responseData(completionHandler: { (response) in
                switch response.result
                {
                case .failure(_):
                    failed()
                case .success(_):
                    if response.response?.statusCode == 200 {
                        success(response.data!)
                    }
                }
            })
    }
    
    func speechToText(url: URL, success: @escaping ((_ data: Data) -> Void), failed: @escaping (() -> Void)) {
        var r  = URLRequest(url: URL(string: "\(baseUrl)/stt")!)
        r.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        r.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        do { data = try Data(contentsOf: url) } catch {}
        let params = ["audio_format": "mp3",
                      "sample_rate": "48000"]
        r.httpBody = createBody(parameters: params,
                                boundary: boundary,
                                data: data,
                                mimeType: "audio/wav",
                                name: "audio_inquiry",
                                filename: "recording.wav")
        
        let task = URLSession.shared.dataTask(with: r, completionHandler: {data, response, error -> Void in
            if let error = error {
                failed()
                return
            }
            if let soundData = data {
                success(soundData)
            } else {
                failed()
            }
        })
        task.resume()
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: false)
        append(data!)
    }
}

extension String {
    func toBool() -> Bool {
        switch self {
        case "True", "true", "yes", "1":
            return true
        case "False", "false", "no", "0":
            return false
        default:
            return false
        }
    }
}
