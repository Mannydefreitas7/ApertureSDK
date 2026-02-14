//
//  Template+Protocol.swift
//  ApertureSDK
//
//  Created by Emmanuel on 2026-02-13.
//

import Foundation

public protocol Template: Identifiable {

    let id = UUID()
    var name: String
    var description: String?
    var settings: ProjectSettings
    var icon: String?
    var project: Project

}
