//
//  DemoMode.swift
//  ClaudeMeter
//
//  Created by Edd on 2026-02-02.
//

#if DEBUG
import Foundation

/// Demo modes for App Store screenshots and testing.
/// Launch with `--demo <mode>` to activate.
enum DemoMode: String, CaseIterable {
    case safeUsage
    case warningUsage
    case criticalUsage
    case exceededUsage
    case withSonnet
    case loading
    case error
    case setupWizard

    static func fromArguments() -> DemoMode? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--demo"),
              index + 1 < args.count else {
            return nil
        }
        return DemoMode(rawValue: args[index + 1])
    }

    var description: String {
        switch self {
        case .safeUsage: "Low usage - safe state"
        case .warningUsage: "Medium usage - warning state"
        case .criticalUsage: "High usage - critical state"
        case .exceededUsage: "Over limit - exceeded state"
        case .withSonnet: "Shows Sonnet usage card"
        case .loading: "Loading spinner visible"
        case .error: "Error banner displayed"
        case .setupWizard: "First-time setup screen"
        }
    }
}
#endif
