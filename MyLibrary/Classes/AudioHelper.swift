//
//  AudioHelper.swift
//  MyLibrary_Tests
//
//  Created by Mohamed AITBELARBI on 06/07/2018.
//  Copyright © 2018 CocoaPods. All rights reserved.
//
//
//  AudioHelper.swift
//  Hrp_iOS
//
//  Created by Mohamed AITBELARBI on 01/06/2018.
//  Copyright © 2018 IMPRIMERIE NATIONALE. All rights reserved.
//

import Foundation
import AVFoundation

public protocol AudioHelperDelegate {
    func recordingPermissionAllowed()
    func recordingPermissionFailed()
    func recordingStarted()
    func recordingStoped()
    func recordingCompleted()
    func recordingFailed()
    func serverError()
    func serverSuccess()
    func soundFinishPlaying()
}

public class AudioHelper: NSObject, AVAudioRecorderDelegate, ServiceDelegate, AVAudioPlayerDelegate {
    
    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder!
    private var audioPlayer : AVAudioPlayer!
    private var levelTimer: Timer!
    private var isFirstTime: Int = 0
    public var microphoneLevelSilenceThreshold: Float = -30
    private var startListening: Bool = false
    private var isSpeaking: Bool = false
    public var isEnrollEnable: Bool = false
    public var isIdentity = false
    
    public var delegate: AudioHelperDelegate?
    
    public func recordPermission() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.delegate?.recordingPermissionAllowed()
                    } else {
                        self.delegate?.recordingPermissionFailed()
                    }
                }
            }
        } catch {
            // failed to record!
        }
    }
    
    public func startRecording(isIdentity: Bool) {
        self.isIdentity = isIdentity
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.wav")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1, //mono . 2: streo
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.prepareToRecord()
            audioRecorder.isMeteringEnabled = true
            
            levelTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(levelTimerCallback), userInfo: nil, repeats: true)
            
            if isEnrollEnable || isIdentity {
                audioRecorder.record(forDuration: TimeInterval(5.0))
            } else {
                audioRecorder.record()
            }
            delegate?.recordingStarted()
        } catch {
            finishRecording(success: false)
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    public  func finishRecording(success: Bool) {
        delegate?.recordingStoped()
        audioRecorder.stop()
        Service.shared.delegate = self
        
        if isEnrollEnable {
            Service.shared.setEnrollUser(url: audioRecorder.url)
        } else {
            Service.shared.getResponse(url: audioRecorder.url)
        }
        
        audioRecorder = nil
        levelTimer.invalidate()
        levelTimer = nil
        
        if success {
            delegate?.recordingCompleted()
        } else {
            delegate?.recordingFailed()
        }
    }
    
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag || isEnrollEnable {
            finishRecording(success: flag)
        }
    }
    
    //This selector/function is called every time our timer (levelTime) fires
    @objc private func levelTimerCallback() {
        //we have to update meters before we can get the metering values
        guard audioRecorder != nil else { return }
        audioRecorder.updateMeters()
        print("average : \(audioRecorder.averagePower(forChannel: 0)) | pack : \(audioRecorder.peakPower(forChannel: 0)) | recording : \(isFirstTime)")
        
        if audioRecorder.averagePower(forChannel: 0) < microphoneLevelSilenceThreshold  {
            if isFirstTime != 1 {
                isFirstTime += 1
            } else {
                isFirstTime = 0
                if isSpeaking  && !isEnrollEnable {
                    finishRecording(success: true)
                    isSpeaking = false
                }
            }
        } else {
            isSpeaking = true
            isFirstTime = 0
        }
    }
    
    //MARK :- ServiceDelegate
    public func playSound(data: Data, startListening: Bool) {
        do {
            try recordingSession.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.volume = 1.0
            audioPlayer.delegate = self
            self.startListening = startListening
            audioPlayer.play()
        } catch {
            print("no audio file")
            delegate?.serverError()
        }
    }
    
    public func showError() {
        delegate?.serverError()
    }
    
    public func serverRecordSuccess() {
        delegate?.serverSuccess()
    }
    
    //MARK :- AVAudioPlayerDelegate
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if startListening {
            startRecording(isIdentity: isIdentity)
        }
        delegate?.soundFinishPlaying()
    }
}
