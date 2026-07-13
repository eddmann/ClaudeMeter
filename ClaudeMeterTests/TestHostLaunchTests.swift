//
//  TestHostLaunchTests.swift
//  ClaudeMeterTests
//

import XCTest
@testable import ClaudeMeter

/// The test bundle is hosted by the app, so running any test launches the real app.
/// Left alone it would bootstrap the menu bar, read the session key from the Keychain
/// (prompting on every run, since the test binary is signed differently from the
/// installed app) and fetch live usage over the network.
///
/// The scheme's test action passes `--demo safeUsage`, which routes the app to
/// `startWithoutBootstrap()`. That keeps the workaround out of the production path,
/// at the cost of living in the scheme where it is easy to delete by accident —
/// hence this test.
final class TestHostLaunchTests: XCTestCase {
    func test_testHost_launchesWithoutBootstrappingTheMenuBar() throws {
        let arguments = ProcessInfo.processInfo.arguments

        guard let flag = arguments.firstIndex(of: "--demo") else {
            return XCTFail(
                """
                The test host was launched without `--demo`, so it will bootstrap the menu bar: \
                read the Keychain and hit the network during tests. Restore the CommandLineArguments \
                in the scheme's TestAction (ClaudeMeter.xcscheme).
                """
            )
        }

        let mode = arguments[arguments.index(after: flag)]
        XCTAssertNotNil(
            DemoMode(rawValue: mode),
            "`--demo \(mode)` is not a DemoMode, so the app will bootstrap normally."
        )
    }
}
