//
//  LiteratureAssistantApp.swift
//  LiteratureAssistant
//
//  Created by Jordan  on 11/9/26.
//

import SwiftUI

@main
struct LiteratureAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            // TODO: Discover is temporarily the root view until the tab bar
            // (Discover / Library / Profile) exists. Move PaperSearchRootView into the Discover tab then.
            PaperSearchRootView()
        }
    }
}
