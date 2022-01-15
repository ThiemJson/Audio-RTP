//
//  ViewController.swift
//  testplayaudio
//
//  Created by vnpt on 12/01/2022.
//

import UIKit
import AVFoundation
import PackageSwiftPcapng
import AudioToolbox

class ViewController: UIViewController {
    var bombSoundEffect: AVAudioPlayer?
    var player : AVAudioPlayer?
    var audioEngine = AVAudioEngine()
    var audioFilePlayer = AVAudioPlayerNode()
    
    var arrayData = [[Float32]]()
    var indexFile = 0
    var timer : Timer?
    
    // Temp buffer
    private var intermediateBuffer = Data()
    private var expectedPacketLength: Int? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
//            guard let path = Bundle.main.path(forResource: "PCMA.raw", ofType: nil) else {
//                print("no file")
//                return
//            }
//            self.initAudioPlayer()
//
//            let _data = try Data(contentsOf: URL(fileURLWithPath: path))
//            let _dataUint8 = [UInt8](_data)
////            let _dataUint8s = _dataUint8.chunked(into: 160)
////            _dataUint8s.forEach { item in
////                let dataTest = Data(bytes: item, count: item.count)
////
////            }
//            Cs2AudioPlayer.shared.playSound(_data)
//            return
            
            
            guard let path = Bundle.main.path(forResource: "rtp.pcap", ofType: nil) else {
                print("no file")
                return
            }
            self.initAudioPlayer()
            

            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let pcap = try Pcap(data: data)
            let pcapPackets = Array(pcap.packets.suffix(pcap.packets.count - 7)).filter { _pcapPacket in
                return _pcapPacket.packetData.count == 214
            }

//            var description = AudioStreamBasicDescription(mSampleRate: 8000, mFormatID: kAudioFormatULaw, mFormatFlags: 0, mBytesPerPacket: 160, mFramesPerPacket: 1, mBytesPerFrame: 160, mChannelsPerFrame: 1, mBitsPerChannel: 8, mReserved: 0)
//            let format = AVAudioFormat(commonFormat: .init(rawValue: 1970037111 )! , sampleRate: 8000, channels: 1, interleaved: false)
//            let format = AVAudioFormat(streamDescription: &description)!
            
//            Cs2AudioPlayer.shared.setAudioFormat(format!)
            
            pcapPackets.forEach { rtpPacket in
                Cs2AudioPlayer.shared.playSound(rtpPacket.packetData)
            }

        } catch {
            print(error)
        }
    }
    
    func ALaw_Decode(_ number: UInt8) -> Int16 {
        var number = number
        var sign: Int = 0
        var position: UInt8 = 0
        var decoded: Int16 = 0
        number ^= 0x55
        if number & 0x80 != 0 {
            number &= ~(1 << 7)
            sign = -1
        }
        position = UInt8(((number & 0xf0) >> 4) + 4)
        if position != 4 {
            decoded = Int16((Int((1 << position)) | (Int((number & 0x0f)) << Int((position - 4))) | Int((1 << (position - 5)))))
        } else {
            decoded = Int16((number << 1) | 1)
        }
        return (sign == 0) ? decoded : (-decoded)
    }
    
    func aFunction(_packets: Array<PcapPacket>, position: Int) -> Array<PcapPacket> {
        let packkets = Array(_packets[0..<position])
        return packkets
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
    //    mutating func buffer() -> AudioBuffer {
    //        return AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(self.count * MemoryLayout<Element>.size), mData: &self)
    //    }
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
                
//                buf = data.makePCMBuffer(format: format)!
                
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
