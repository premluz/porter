import Darwin
import Foundation

struct TrialMetrics: Encodable {
    let id: String
    let engine: String
    let matched: Bool
    let wallSeconds: Double
    let clientCPUSeconds: Double
}

enum Metrics {
    static func cpuSeconds() throws -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else {
            throw SpikeError.invalid("getrusage failed: errno \(errno)")
        }
        let seconds = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
        let micros = Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec)
        return seconds + micros / Double(USEC_PER_SEC)
    }

    static func printJSON(_ metric: TrialMetrics) throws {
        let data = try JSONEncoder().encode(metric)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SpikeError.invalid("Could not encode metrics as UTF-8")
        }
        print(text)
    }
}
