import Foundation

// MARK: - Search Method Configuration

enum SearchMethod: String, CaseIterable {
    case domain
    case htmlTitle = "html_title"

    var displayName: String {
        switch self {
        case .domain:
            "Domain"
        case .htmlTitle:
            "HTML Title"
        }
    }

    var description: String {
        switch self {
        case .domain:
            "Search using the domain name extracted from the URL"
        case .htmlTitle:
            "Search using the HTML title extracted from the webpage"
        }
    }
}

struct SearchMethodConfig {
    let method: SearchMethod
    let isEnabled: Bool
    let priority: Int // Lower numbers = higher priority

    static let defaultConfig: [SearchMethodConfig] = [
        SearchMethodConfig(method: .domain, isEnabled: true, priority: 1),
        SearchMethodConfig(method: .htmlTitle, isEnabled: true, priority: 2),
    ]

    /// Configuration for domain-only search (legacy mode)
    static let domainOnlyConfig: [SearchMethodConfig] = [
        SearchMethodConfig(method: .domain, isEnabled: true, priority: 1),
        SearchMethodConfig(method: .htmlTitle, isEnabled: false, priority: 2),
    ]

    /// Configuration for HTML title-only search (for testing)
    static let htmlTitleOnlyConfig: [SearchMethodConfig] = [
        SearchMethodConfig(method: .domain, isEnabled: false, priority: 1),
        SearchMethodConfig(method: .htmlTitle, isEnabled: true, priority: 2),
    ]
}

// MARK: - Search Configuration Manager

class SearchConfigurationManager {
    private let userDefaults = UserDefaults.standard
    private let configKey = "search_method_configuration"

    static let shared = SearchConfigurationManager()

    private init() {}

    /// Get the current search method configuration
    var currentConfig: [SearchMethodConfig] {
        if let data = userDefaults.data(forKey: configKey),
           let savedConfig = try? JSONDecoder().decode([SearchMethodConfigData].self, from: data)
        {
            return savedConfig.map { configData in
                SearchMethodConfig(
                    method: SearchMethod(rawValue: configData.method) ?? .domain,
                    isEnabled: configData.isEnabled,
                    priority: configData.priority
                )
            }
        }
        return SearchMethodConfig.defaultConfig
    }

    /// Update the search method configuration
    func updateConfig(_ config: [SearchMethodConfig]) {
        let configData = config.map { methodConfig in
            SearchMethodConfigData(
                method: methodConfig.method.rawValue,
                isEnabled: methodConfig.isEnabled,
                priority: methodConfig.priority
            )
        }

        if let data = try? JSONEncoder().encode(configData) {
            userDefaults.set(data, forKey: configKey)
        }
    }

    /// Reset to default configuration
    func resetToDefault() {
        userDefaults.removeObject(forKey: configKey)
    }

    /// Quick toggle for enabling/disabling HTML title search
    func toggleHTMLTitleSearch() {
        var config = currentConfig
        if let index = config.firstIndex(where: { $0.method == .htmlTitle }) {
            config[index] = SearchMethodConfig(
                method: .htmlTitle,
                isEnabled: !config[index].isEnabled,
                priority: config[index].priority
            )
            updateConfig(config)
        }
    }

    /// Check if a specific search method is enabled
    func isMethodEnabled(_ method: SearchMethod) -> Bool {
        currentConfig.first { $0.method == method }?.isEnabled ?? false
    }
}

// MARK: - Private Data Structure for UserDefaults

private struct SearchMethodConfigData: Codable {
    let method: String
    let isEnabled: Bool
    let priority: Int
}
