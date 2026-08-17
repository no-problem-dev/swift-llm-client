import Foundation

// MARK: - ModelDescriptor

/// One model, flattened into the facts a chooser needs.
///
/// A ``ModelPreset`` is generic over its provider, so a list mixing providers cannot hold the
/// presets themselves. This is what they flatten to: plain values, `Codable`, carrying no
/// provider type. A picker can render one of these without knowing which provider it came from,
/// and a server can send one to a client that does not link the provider at all.
public struct ModelDescriptor: Codable, Sendable, Identifiable, Hashable {
    /// The identifier to store and compare, as `"<providerID>:<rawValue>"`.
    public let id: String

    /// Which provider serves this model. Matches ``ModelPreset/providerID``.
    public let providerID: String

    /// The identifier the provider's API is called with.
    public let modelID: String

    public let displayName: String
    public let shortName: String

    /// What the model is good at, what it costs, and how much it can hold.
    public let profile: ModelProfile

    public init(
        id: String,
        providerID: String,
        modelID: String,
        displayName: String,
        shortName: String,
        profile: ModelProfile
    ) {
        self.id = id
        self.providerID = providerID
        self.modelID = modelID
        self.displayName = displayName
        self.shortName = shortName
        self.profile = profile
    }
}

public extension ModelPreset {
    /// Flattens this preset into a value a chooser can hold alongside other providers'.
    var descriptor: ModelDescriptor {
        ModelDescriptor(
            id: globalID,
            providerID: Self.providerID,
            modelID: modelID,
            displayName: displayName,
            shortName: shortName,
            profile: profile
        )
    }

    /// Every preset this provider still serves, flattened.
    static var descriptors: [ModelDescriptor] {
        allCases.map(\.descriptor)
    }
}

// MARK: - ModelCatalog

/// The models a caller offers, drawn from however many providers.
///
/// Build one at startup from the presets that make sense for the app, then read it wherever the
/// choice is shown or resolved. The catalog is the single place that knows which models exist,
/// so adding a provider is one more `descriptors` in the initialiser and nothing else.
public struct ModelCatalog: Sendable, Hashable {
    public let models: [ModelDescriptor]

    /// Falls back to this when a stored choice no longer names a model in ``models``.
    public let defaultModelID: String

    /// - Parameters:
    ///   - models: Every model on offer. Order is kept, so sort before passing if it matters.
    ///   - defaultModelID: The identifier to fall back to. When it names no model in `models`,
    ///     the first model is used instead, so ``resolve(_:)`` always answers with something
    ///     that exists.
    public init(models: [ModelDescriptor], defaultModelID: String) {
        self.models = models
        if models.contains(where: { $0.id == defaultModelID }) {
            self.defaultModelID = defaultModelID
        } else {
            self.defaultModelID = models.first?.id ?? defaultModelID
        }
    }

    /// The providers present in ``models``, in the order they first appear.
    public var providerIDs: [String] {
        var seen: Set<String> = []
        return models.compactMap { seen.insert($0.providerID).inserted ? $0.providerID : nil }
    }

    /// The models one provider serves, in catalog order.
    public func models(providerID: String) -> [ModelDescriptor] {
        models.filter { $0.providerID == providerID }
    }

    public func model(id: String) -> ModelDescriptor? {
        models.first { $0.id == id }
    }

    /// Turns a stored choice into one that still exists.
    ///
    /// A model the app used to offer can be dropped — retired by the vendor, or removed from the
    /// catalog — while the identifier stays in the user's settings. Reading it back through here
    /// answers with ``defaultModelID`` instead of a model nothing can serve.
    public func resolve(_ modelID: String?) -> String {
        guard let modelID, model(id: modelID) != nil else {
            return defaultModelID
        }
        return modelID
    }
}
