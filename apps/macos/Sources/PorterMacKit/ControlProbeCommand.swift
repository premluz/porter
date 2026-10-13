import NativeSources

/// The command-line entry to the control probe, so the app's own executable (the one with the Accessibility
/// permission) can run it.
public enum ControlProbeCommand {
    public static func run(bundleId: String, seconds: Int) async -> String {
        await ControlProbe.run(bundleId: bundleId, duration: .seconds(seconds))
    }
}
