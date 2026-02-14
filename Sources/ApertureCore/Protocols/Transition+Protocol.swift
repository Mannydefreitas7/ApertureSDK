//
//  Transition+Protocol.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

public protocol Transition {

    public var id: UUID
    public var type: TransitionType
    public var duration: Double // seconds
    public var parameters: [String: Double]

        /// Application-side clip IDs (optional, for rendering)
    public var fromClipId: UUID?
    public var toClipId: UUID?

}
