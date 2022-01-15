//
//  Cs2AudioPlayer.swift
//  testplayaudio
//
//  Created by vnpt on 12/01/2022.
//

import Foundation
import AVFoundation
import Accelerate

class Cs2AudioPlayer {
    private init(){}
    static let shared = Cs2AudioPlayer()
    
    private var audioEngine = AVAudioEngine()
    var audioPlayerNode = AVAudioPlayerNode()
    
    private var bufferArray = [Float32]()
    var bufferQueue = Queue<[Float32]>()
    var playQueue = DispatchQueue(label: "playQueue", attributes: .concurrent)
    
    var bufferSize = 1024
    var bufferByteSize = MemoryLayout<Float>.size * 1024
    
    private var audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)
    
    public func setBufferArray(_ array : [Float32]) {
        
        //        let randomInt = Int.random(in: 0..<90)
        //        if randomInt == 3 {
        //            self.bufferQueue.enqueue(Array(repeating: Float32(0), count: 1024))
        //            return
        //        }
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
                let mainMixer = audioEngine.mainMixerNode
                audioEngine.attach(audioPlayerNode)
                audioEngine.connect(audioPlayerNode, to: mainMixer, format: audioFormat!)
                
                audioEngine.prepare()
                try audioEngine.start()
                
                audioPlayerNode.play()
                return
            }
            
            self.audioPlayerNode.stop()
            self.audioEngine.stop()
        } catch {
            print("isReceiveAudio error \(error)")
        }
    }
    
    public func playSound(_ _data: Data? = nil ) {
        
        guard let data = _data else {
            return
        }
        
        //            let inputFormat = self.audioFormat!
        
        
        
        //
        //            if _data?.count != 214 {
        //                return
        //            }
        
        // Timestamp
        //            let timestamp = ByteUtil.bytesToUInt16([data[44],data[45])
        
        // Sequence number
        let sequence = ByteUtil.bytesToUInt16([UInt8](Data(data.prefix(46).suffix(2)))[0..<2])
        let timeStamp = ByteUtil.bytesToUInt32([UInt8](Data(data.prefix(50).suffix(4)))[0..<4])
        let type = [UInt8](data)[43] // 8: PCMA; 0: PCMU
        
        let byteData = Data(bytes: [UInt8]((data).suffix(160)))
        
        let dataPayload = Data.init(data.suffix(160))
        
        self.bufferSize = dataPayload.count
        self.bufferByteSize = MemoryLayout<Float>.size * self.bufferSize
        
        // Decode PCMA
        
        //        if !(sequence >= 19303 && sequence <= 19716) {
        //            return
        //        }
        
        //        print(sequence)
        
        let byteDataUInt8 = [UInt8](dataPayload)
        var byteDataInt16 = [Int16]()
        var byteDataFLoat32 = [Float32](repeating: 0.0, count: bufferSize)
        
        byteDataUInt8.forEach { uint8 in
            byteDataInt16.append(type == 8 ? ALaw_Decode(uint8) : ULaw_Decode(uint8))
        }
        
        //        byteDataUInt8.forEach { uint8 in
        //            byteDataInt16.append(type == 8 ? ALaw_Decode(uint8) : ULaw_Decode(uint8))
        //            //            byteDataFLoat32.append(ByteUtil.bytesToFloat32( ArraySlice(arrayLiteral: uint8) ))
        //        }
        //
        //        byteDataInt16.forEach { int16 in
        //            byteDataFLoat32.append(Float32(int16))
        //        }
        //
        //        let _data = Data(bytes: byteDataFLoat32, count: byteDataFLoat32.count)
        
        //        var description = AudioStreamBasicDescription(mSampleRate: 8000, mFormatID: kAudioFormatALaw, mFormatFlags: 0, mBytesPerPacket: 160, mFramesPerPacket: 1, mBytesPerFrame: 160, mChannelsPerFrame: 1, mBitsPerChannel: 8, mReserved: 0)
        //        let format = AVAudioFormat(streamDescription: &description)!
        
        
        if let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: UInt32(bufferSize)) {
            
            let monoChannel = buffer.floatChannelData![0]
            
            // Int16 ranges from -32768 to 32767 -- we want to convert and scale these to Float values between -1.0 and 1.0
            var scale = Float(Int16.max) + 1.0
            vDSP_vflt16(byteDataInt16, 1, &byteDataFLoat32, 1, vDSP_Length(bufferSize)) // Int16 to Float
            vDSP_vsdiv(byteDataFLoat32, 1, &scale, &byteDataFLoat32, 1, vDSP_Length(bufferSize)) // divide by scale
            
            memcpy(monoChannel, byteDataFLoat32, bufferByteSize)
            buffer.frameLength = UInt32(bufferSize)
            audioPlayerNode.volume = 1.0
            audioPlayerNode.scheduleBuffer(buffer, completionHandler: nil) // load more buffers in the completionHandler
            
        }
        
        //        let buffer = _data.makePCMBuffer(format: audioFormat!)
        
        
        //        audioPlayerNode.scheduleBuffer(buffer!, completionHandler: {
        //
        //        })
        
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
    
    //  Converted to Swift 5.5 by Swiftify v5.5.17943 - https://swiftify.com/
    func ULaw_Decode(_ number: UInt8) -> Int16 {
        var number = number
        let MULAW_BIAS: UInt16 = 33
        var sign: Int = 0
        var position: UInt8 = 0
        var decoded: Int16 = 0
        number = ~number
        if number & 0x80 != 0 {
            number &= ~(1 << 7)
            sign = -1
        }
        position = UInt8(((number & 0xf0) >> 4) + 5)
        decoded = Int16((Int((1 << position)) | (Int((number & 0x0f)) << Int((position - 4))) | Int((1 << (position - 5)))) - Int(MULAW_BIAS))
        return (sign == 0) ? decoded : (-decoded)
    }
    
    func toPCMBuffer(data: NSData, audioFormat format: AVAudioFormat) -> AVAudioPCMBuffer? {
        //        let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)!  // given NSData audio format
        guard let PCMBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count)) else {
            return nil
        }
        PCMBuffer.frameLength = PCMBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: Int(PCMBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return PCMBuffer
    }
    
    
    //  Converted to Swift 5.5 by Swiftify v5.5.17943 - https://swiftify.com/
    /*
     * Description:
     *  Decodes an 8-bit unsigned integer using the A-Law.
     * Parameters:
     *  number - the number who will be decoded
     * Returns:
     *  The decoded number
     */
    //    func ALaw_Decode(_ number: UInt8) -> Int16 {
    //        var number = number
    //        var sign: UInt8 = 0x00
    //        var position: UInt8 = 0
    //        var decoded: Int16 = 0
    //        number ^= 0x55
    //        if number & 0x80 != 0 {
    //            number &= ~(1 << 7)
    //            sign = -1
    //        }
    //        position = UInt8(((number & 0xf0) >> 4) + 4)
    //        if position != 4 {
    //            decoded = Int16((Int((1 << position)) | (Int((number & 0x0f)) << Int((position - 4))) | Int((1 << (position - 5)))))
    //        } else {
    //            decoded = Int16((number << 1) | 1)
    //        }
    //        return (sign == 0) ? decoded : (-decoded)
    //    }
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

