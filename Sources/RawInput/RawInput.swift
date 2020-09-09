import Foundation

/// A wrapper for getting raw input.
///
/// ### Usage
///
/// The `RawInput` class can be used like this:
///
///     RawInput.observe(as: OutputTypes.Character.self) { value in
///         // ...
///     }
///
/// Make sure to specify one of the following `OutputTypes`:
/// - `OutputTypes.Scalar`: Will return `Unicode.Scalar` values
/// - `OutputTypes.Character`: Will return `Character` values
/// - `OutputTypes.Raw`: Will return `UInt8` values
public final class RawInput {
    public typealias Observer = (String) -> Void
    
    private let stdin: FileHandle = .standardInput
    private var restore: termios!
    private var observers: [Observer] = []
    
    private func makeRaw<T>() -> T {
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        let pointee = pointer.pointee
        pointer.deallocate()
        return pointee
    }
    
    private func enableRawMode(for fileHandle: FileHandle) -> termios {
        var raw: termios = makeRaw()
        tcgetattr(fileHandle.fileDescriptor, &raw)

        let original = raw

        raw.c_lflag &= ~(UInt(ECHO | ICANON))
        tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &raw);
        return original
    }

    private func restoreMode(for fileHandle: FileHandle, restore: termios) {
        var restore = restore
        tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &restore);
    }
    
    fileprivate func begin() {
        self.restore = enableRawMode(for: stdin)
        
        DispatchQueue.main.async {
            var rawValue: UInt8 = 0
            var buffer: [UInt8] = []
            while read(self.stdin.fileDescriptor, &rawValue, 1) == 1 {
                guard rawValue != 0x04 else { break }
                buffer.append(rawValue)
                if let value = String(bytes: buffer, encoding: .utf8) {
                    self.observers.forEach({ $0(value) })
                    buffer = []
                }
            }
        }
    }
    
    public func end() {
        restoreMode(for: stdin, restore: restore)
    }
}

public protocol RawInputOutputType {
    associatedtype Value
    static func map(_ rawValue: UInt8) -> Value
}

public enum OutputTypes {}

extension OutputTypes {
    public enum Scalar: RawInputOutputType {
        public typealias Value = Unicode.Scalar
        
        public static func map(_ rawValue: UInt8) -> Value {
            return Value(rawValue)
        }
    }
}

extension OutputTypes {
    public enum Character: RawInputOutputType {
        public typealias Value = Swift.Character
        
        public static func map(_ rawValue: UInt8) -> Value {
            return Value(Scalar.map(rawValue))
        }
    }
}

extension OutputTypes {
    public enum Raw: RawInputOutputType {
        public typealias Value = Swift.UInt8
        
        public static func map(_ rawValue: UInt8) -> Value {
            return rawValue
        }
    }
}

fileprivate final class _RawInput {
    static var instance: Any? = nil
}

extension RawInput {
    public static func observe(handler observer: @escaping RawInput.Observer) {
        guard let input = _RawInput.instance as? RawInput else {
            _RawInput.instance = RawInput()
            RawInput.observe(handler: observer)
            return
        }
        guard input.restore != nil else {
            input.begin()
            RawInput.observe(handler: observer)
            return
        }
        input.observers.append(observer)
    }
}
