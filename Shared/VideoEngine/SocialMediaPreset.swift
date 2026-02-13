//
//  SocialMediaPreset.swift
//  VideoEditor
//
//  Created by Emmanuel on 2/10/26.
//

import Foundation

enum SocialMediaPreset: String, CaseIterable {

    case tiktok
    case instagramReels,
    instagramFeed, instagramStory
    case youtubeShorts, youtube
    case twitter
    case facebook
    case linkedin
    case vimeo
    case snapchat
    case pinterest
    case reddit
    case custom

    var displayName: String {
        return self.rawValue
    }
}
