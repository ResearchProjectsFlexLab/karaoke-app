//
//  AppModel.swift
//  Karaoke
//
//  Created by Prisha Marpu on 10/22/26.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    /// Shared between the window and the immersive stage.
    let session = KaraokeSession()
}
