//
//  ViewController.swift
//  testplayaudio
//
//  Created by vnpt on 12/01/2022.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    var bombSoundEffect: AVAudioPlayer?
    var player : AVAudioPlayer?
    var audioEngine = AVAudioEngine()
    var audioFilePlayer = AVAudioPlayerNode()
    
    var arrayData = [[Float32]]()
    var indexFile = 0
    var timer : Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        self.initAudioPlayer()
        guard let path = Bundle.main.path(forResource: "m1f1_ulaw.wav", ofType: nil) else {
                return }
            let url = URL(fileURLWithPath: path)
            
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()

            } catch let error {
                print(error.localizedDescription)
            }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            var wavInFloatArray = self.readWavIntoFloats(fname: "m1f1_ulaw", ext: "wav")
            wavInFloatArray.append(contentsOf: wavInFloatArray)
            wavInFloatArray.append(contentsOf: wavInFloatArray)
            wavInFloatArray.append(contentsOf: wavInFloatArray)
            wavInFloatArray.append(contentsOf: wavInFloatArray)
            wavInFloatArray.append(contentsOf: wavInFloatArray)
            wavInFloatArray.append(contentsOf: wavInFloatArray)
            self.arrayData = wavInFloatArray.chunked(into: 100)
            self.initAudioPlayer()
            self.timer = Timer.scheduledTimer(timeInterval: 0.001, target: self, selector: #selector(self.playAudio), userInfo: nil, repeats: true)
        }
    }
    
    private func initAudioPlayer() {
        Cs2AudioPlayer.shared.isReceiveAudio(true)
    }
    
    @objc func playAudio() {
        
        if self.indexFile >= self.arrayData.count {
            self.timer?.invalidate()
            return
        }
        
        print(arrayData[self.indexFile].prefix(10))
        Cs2AudioPlayer.shared.setBufferArray(arrayData[self.indexFile])
        Cs2AudioPlayer.shared.playSound()
        indexFile += 1
    }
    
    func audioBufferToNSData(PCMBuffer: AVAudioPCMBuffer) -> NSData {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: channelCount)
        let data = NSData(bytes: channels[0], length:Int(PCMBuffer.frameLength * PCMBuffer.format.streamDescription.pointee.mBytesPerFrame))
        
        return data
    }
    
    func readWavIntoFloats(fname: String, ext: String) -> [Float] {
        
        let url = Bundle.main.url(forResource: fname, withExtension: ext)
        let file = try! AVAudioFile(forReading: url!)
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 2, interleaved: false) ?? AVAudioFormat()
        
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length))!
        try! file.read(into: buf)
        
        // this makes a copy, you might not want that
        let floatArray = Array(UnsafeBufferPointer(start: buf.floatChannelData?[0], count:Int(buf.frameLength)))
        
        return floatArray
        
    }
}

extension AVAudioPCMBuffer {
    func data() -> Data {
        let channelCount = 1  // given PCMBuffer channel count is 1
        let channels = UnsafeBufferPointer(start: self.floatChannelData, count: channelCount)
        let ch0Data = NSData(bytes: channels[0], length:Int(self.frameCapacity * self.format.streamDescription.pointee.mBytesPerFrame))
        return ch0Data as Data
    }
}

extension AudioBuffer {
    func array() -> [Float] {
        return Array(UnsafeBufferPointer(self))
    }
}

extension AVAudioPCMBuffer {
    func array() -> [Float] {
        return self.audioBufferList.pointee.mBuffers.array()
    }
}

extension Array where Element: FloatingPoint {
    mutating func buffer() -> AudioBuffer {
        return AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(self.count * MemoryLayout<Element>.size), mData: &self)
    }
}

extension ViewController {
    func doStuff() {
        do {
            guard let url = Bundle.main.url(forResource: "m1f1_ulaw", withExtension: "wav") else { return }
            let file = try AVAudioFile(forReading: url)
            if let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 2, interleaved: false), var buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) {
                
                
                
                try file.read(into: buf)
                guard let floatChannelData = buf.floatChannelData else { return }
                let frameLength = Int(buf.frameLength)
                
                let samples = Array(UnsafeBufferPointer(start:floatChannelData[0], count:frameLength))
                //        let samples2 = Array(UnsafeBufferPointer(start:floatChannelData[1], count:frameLength))
                
                //                print("samples")
                //                print(samples.count)
                
                var data = Data()
                for buf in samples {
                    data.append(withUnsafeBytes(of: buf) { Data($0) })
                }
                
                buf = data.makePCMBuffer(format: format)!
                
                // connect the nodes, and use the data to play
                let mainMixer = audioEngine.mainMixerNode
                audioEngine.attach(audioFilePlayer)
                audioEngine.connect(audioFilePlayer, to: mainMixer, format: buf.format)
                
                try audioEngine.start()
                
                audioFilePlayer.play()
                audioFilePlayer.scheduleBuffer(buf, completionHandler: nil)
            }
        } catch {
            print("Audio Error: \(error)")
        }
        
        return
        if let url = Bundle.main.url(forResource: "m1f1_ulaw", withExtension: "wav") {
            do {
                let file = try AVAudioFile(forReading: url)
                if let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 2, interleaved: false) {
                    if let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) {
                        try file.read(into: buf)
                        
                        // connect the nodes, and use the data to play
                        let mainMixer = audioEngine.mainMixerNode
                        audioEngine.attach(audioFilePlayer)
                        audioEngine.connect(audioFilePlayer, to: mainMixer, format: buf.format)
                        
                        try audioEngine.start()
                        
                        audioFilePlayer.play()
                        audioFilePlayer.scheduleBuffer(buf, completionHandler: nil)
                    }
                }
            } catch {
                print(error)
            }
            
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
