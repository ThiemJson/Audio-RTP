//
//  Cs2AudioPlayer.swift
//  testplayaudio
//
//  Created by vnpt on 12/01/2022.
//

import Foundation
import AVFoundation

class Cs2AudioPlayer {
    private init(){}
    static let shared = Cs2AudioPlayer()
    
    private var audioEngine = AVAudioEngine()
    private var audioPlayerNode = AVAudioPlayerNode()
    
    private var bufferArray = [Float32]()
    var bufferQueue = Queue<[Float32]>()
    var playQueue = DispatchQueue(label: "playQueue", attributes: .concurrent)
    
    private var audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)
    
    public func setBufferArray(_ array : [Float32]) {
        self.bufferQueue.enqueue(array)
//        if array.count < 1024 {
//            let tempArray = Array(repeating: Float32(0), count: 1024 - array.count)
//            self.bufferArray = array
//            self.bufferArray.append(contentsOf: tempArray)
//            self.bufferQueue.enqueue(self.bufferArray)
//        } else {
//            self.bufferQueue.enqueue(array)
//        }
    }
    
    public func setAudioFormat( _ format: AVAudioFormat ) {
        self.audioFormat = format
    }
    
    public func isReceiveAudio(_ bool : Bool) {
        do {
            if bool {
                try self.audioEngine.start()
                return
            }
            
            self.audioPlayerNode.stop()
            self.audioEngine.stop()
        } catch {
            print("isReceiveAudio error \(error)")
        }
    }
    
    public func playSound() {
        self.playQueue.sync {
            var data = Data()
            
            if self.bufferQueue.isEmpty {
                return
            }
            
            guard let dataFloat32 = self.bufferQueue.dequeue() else { return }
            data = data.fromFloat32(dataFloat32)
            
            guard let buffer = data.makePCMBuffer(format: self.audioFormat ?? AVAudioFormat()) else {
                print("cannit init buffer")
                return
            }
            
            let engine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()
            
            let mainMixer = engine.mainMixerNode
            engine.attach(playerNode)
            engine.connect(playerNode, to: mainMixer, format: buffer.format)
            
            engine.prepare()
            do {
                try engine.start()
            } catch {
                print(error)
            }
            
            playerNode.play()
            playerNode.scheduleBuffer(buffer, completionHandler: {
                engine.stop()
            })
        }
        
    }
}

extension Data {
    init(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        self.init(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
    
    func makePCMBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let streamDesc = format.streamDescription.pointee
        let frameCapacity = UInt32(count) / streamDesc.mBytesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        
        buffer.frameLength = buffer.frameCapacity
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        
        withUnsafeBytes { (bufferPointer) in
            guard let addr = bufferPointer.baseAddress else { return }
            audioBuffer.mData?.copyMemory(from: addr, byteCount: Int(audioBuffer.mDataByteSize))
        }
        
        return buffer
    }
    
    func fromFloat32(_ array : [Float32]) -> Data {
        var data = Data()
        for buf in array {
            data.append(Swift.withUnsafeBytes(of: buf) { Data($0) })
        }
        return data
    }
}

