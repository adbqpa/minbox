//
//  MBConfiguration.swift
//  Mindbox
//
//  Created by Mikhail Barilov on 13.01.2021.
//  Copyright © 2021 Mikhail Barilov. All rights reserved.
//

import Foundation
/// This struct contains init options and  behavior configuration options
///
/// - Throws:`MindboxError.internalError` for invalid initialization parameters

public struct MBConfiguration: Codable {
    public let endpoint: String
    public let domain: String
    public var previousInstallationId: String?
    public var previousDeviceUUID: String?
    public var subscribeCustomerIfCreated: Bool
    public var shouldCreateCustomer: Bool

    /// Init with params
    ///
    /// - Parameter endpoint: Used for app identification
    /// - Parameter domain: Used for generating baseurl for REST
    /// - Parameter previousInstallationId: Used to create tracking continuity by uuid
    /// - Parameter previousDeviceUUID: Used instead of the generated value
    /// - Parameter subscribeCustomerIfCreated: Flag which determines subscription status of the user. Default value is `false`.
    /// - Parameter shouldCreateCustomer: Flag which determines create or not anonymous users. Usable only during first initialisation. Default value is `true`.
    ///
    /// - Throws:`MindboxError.internalError` for invalid initialization parameters
    public init(
        endpoint: String,
        domain: String,
        previousInstallationId: String? = nil,
        previousDeviceUUID: String? = nil,
        subscribeCustomerIfCreated: Bool = false,
        shouldCreateCustomer: Bool = true
    ) throws {
        self.endpoint = endpoint
        self.domain = domain

        guard let url = URL(string: "https://" + domain), URLValidator(url: url).evaluate() else {
            throw MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Invalid domain. Domain is unreachable"
            ))
        }

        guard !endpoint.isEmpty else {
            throw MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "Value endpoint can not be empty"
            ))
        }

        if let previousInstallationId = previousInstallationId, !previousInstallationId.isEmpty {
            if UUID(uuidString: previousInstallationId) != nil && UDIDValidator(udid: previousInstallationId).evaluate() {
                self.previousInstallationId = previousInstallationId
            } else {
                Mindbox.logger.log(level: .error, message: "previousInstallationId doesn't match the UUID format")
                self.previousInstallationId = ""
            }
        }

        if let previousDeviceUUID = previousDeviceUUID, !previousDeviceUUID.isEmpty {
            if UUID(uuidString: previousDeviceUUID) != nil && UDIDValidator(udid: previousDeviceUUID).evaluate() {
                self.previousDeviceUUID = previousDeviceUUID
            } else {
                Mindbox.logger.log(level: .error, message: "previousDeviceUUID doesn't match the UUID format")
                self.previousDeviceUUID = ""
            }
        }
        
        self.subscribeCustomerIfCreated = subscribeCustomerIfCreated
        self.shouldCreateCustomer = shouldCreateCustomer
    }

    /// Init with plist file
    ///
    /// ```
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    /// <plist version="1.0">
    /// <dict>
    ///    <key>endpoint</key>
    ///    <string>app-with-hub-IOS</string>
    ///    <key>domain</key>
    ///    <string>api.mindbox.ru</string>
    ///    <key>previousInstallationId</key>
    ///    <string></string>
    ///    <key>previousDeviceUUID</key>
    ///    <string></string>
    ///    ...
    /// </dict>
    /// </plist>
    /// ```
    /// - Parameter plistName: name of plist file without extension
    /// - Throws:`MindboxError.internalError` for invalid initialization parameters or incorrect format file
    public init(plistName: String) throws {
        let decoder = PropertyListDecoder()
        var findeURL: URL?

        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: plistName, withExtension: "plist") {
                findeURL = url
                break
            }
        }

        guard let url = findeURL else {
            throw MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "file with name \(plistName) not found"
            ))
        }

        guard let data = try? Data(contentsOf: url) else {
            throw MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "file with name \(plistName) cannot be read"
            ))
        }

        guard let configuration = try? decoder.decode(MBConfiguration.self, from: data) else {
            throw MindboxError(.init(
                errorKey: .invalidConfiguration,
                reason: "file with name \(plistName) contains invalid properties"
            ))
        }
        self = configuration
    }

    enum CodingKeys: String, CodingKey {
        case endpoint
        case domain
        case previousInstallationId
        case previousDeviceUUID
        case subscribeCustomerIfCreated
        case shouldCreateCustomer
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let endpoint = try values.decode(String.self, forKey: .endpoint)
        let domain = try values.decode(String.self, forKey: .domain)
        var previousInstallationId: String?
        if let value = try? values.decode(String.self, forKey: .previousInstallationId) {
            if !value.isEmpty {
                previousInstallationId = value
            }
        }
        var previousDeviceUUID: String?
        if let value = try? values.decode(String.self, forKey: .previousDeviceUUID) {
            if !value.isEmpty {
                previousDeviceUUID = value
            }
        }
        let subscribeCustomerIfCreated = try values.decodeIfPresent(Bool.self, forKey: .subscribeCustomerIfCreated) ?? false
        let shouldCreateCustomer = try values.decodeIfPresent(Bool.self, forKey: .shouldCreateCustomer) ?? true
        try self.init(
            endpoint: endpoint,
            domain: domain,
            previousInstallationId: previousInstallationId,
            previousDeviceUUID: previousDeviceUUID,
            subscribeCustomerIfCreated: subscribeCustomerIfCreated,
            shouldCreateCustomer: shouldCreateCustomer
        )
    }
}

struct ConfigValidation {

    struct ChangedState: OptionSet {
        let rawValue: Int

        static let none                 = ChangedState(rawValue: 1 << 0)
        static let endpoint             = ChangedState(rawValue: 1 << 1)
        static let domain               = ChangedState(rawValue: 1 << 2)
        static let shouldCreateCustomer = ChangedState(rawValue: 1 << 3)

        /// Change affecting the REST API for the application
        static let rest: ChangedState = [.endpoint, .domain]
    }

    var changedState: ChangedState = .none

    mutating func compare(_ lhs: MBConfiguration?, _ rhs: MBConfiguration?) {
        if !(lhs?.domain == rhs?.domain && lhs?.endpoint == rhs?.endpoint) {
            changedState = .rest
        } else if !(lhs?.shouldCreateCustomer == rhs?.shouldCreateCustomer) {
            changedState = .shouldCreateCustomer
        } else {
            changedState = .none
        }
    }

}
