import Foundation

// MARK: - ModelPreset

/// What every provider's `Preset` has in common.
///
/// Each provider ships its own `Preset` — `GeminiModel.Preset`, `GPTModel.Preset`, and so on —
/// and they already carry the same members. Without a protocol tying them together there is no
/// way to hold "some model the user picked" or to build one list out of several providers, so
/// every caller that shows a model picker ends up writing the same wrapper enum: a case per
/// provider, a `switch` per member, and a hand-rolled identifier to store the choice under.
///
/// Conforming the presets lets that list be built from the presets themselves. Nothing here asks
/// a provider for information it did not already publish.
public protocol ModelPreset: RawRepresentable, CaseIterable, Identifiable, Sendable
    where RawValue == String {
    /// Identifies the provider these presets belong to, and namespaces ``ModelPreset/globalID``.
    ///
    /// Stored, so keep it stable: changing it orphans identifiers already written to disk.
    static var providerID: String { get }

    /// The name to show, spelled the way the vendor spells it (`"Gemini 3.6 Flash"`).
    var displayName: String { get }

    /// A shorter name for places a full one will not fit (`"3.6 Flash"`).
    var shortName: String { get }

    /// What the model is good at, what it costs, and how much it can hold.
    var profile: ModelProfile { get }

    /// The identifier the provider's API is called with (`"gemini-3.6-flash"`).
    var modelID: String { get }
}

public extension ModelPreset {
    var id: String { rawValue }

    /// Identifies this preset across providers, as `"<providerID>:<rawValue>"`.
    ///
    /// `rawValue` alone is only unique within one provider, so this is what to store and what to
    /// compare when models from several providers sit in the same list.
    var globalID: String { "\(Self.providerID):\(rawValue)" }

    /// Reads a preset back from ``ModelPreset/globalID``.
    ///
    /// Returns `nil` when the identifier names another provider, or a preset this version no
    /// longer serves — a stored choice pointing at a retired model, which the caller resolves by
    /// falling back to its default.
    init?(globalID: String) {
        let parts = globalID.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == Self.providerID else {
            return nil
        }
        self.init(rawValue: String(parts[1]))
    }
}
