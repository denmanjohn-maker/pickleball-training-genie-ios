import SwiftUI
import XCTest
@testable import PickleballTrainingGenie

/// Simulator renderings with fixture data, not interactive VoiceOver testing.
@MainActor
final class TodayLayoutTests: XCTestCase {
    func testFiveDestinationsRenderAtDeviceSize() async throws {
        try await render(MainTabView(), name: "Main navigation")
        for section in AppSection.allCases {
            try await render(section.destination(onBrowseAllDrills: {}), name: section.title)
        }
    }

    func testTodayAndNavigationRenderAtAccessibilityTextSize() async throws {
        try await render(
            MainTabView().dynamicTypeSize(.accessibility3),
            name: "Navigation with accessibility text"
        )
        try await render(
            TodayView(onBrowseAllDrills: {}).dynamicTypeSize(.accessibility3),
            name: "Today with accessibility text"
        )
    }

    func testSavedRawWorkoutReviewRendersWithoutSetupAtTop() async throws {
        try await render(
            WorkoutView(reviewSavedWorkout: true),
            name: "Saved text workout review",
            rawWorkout: true
        )
    }

    private func render<V: View>(_ view: V, name: String, rawWorkout: Bool = false) async throws {
        let scope = "layout-test-\(UUID().uuidString)"
        defer {
            StubURLProtocol.handler = nil
            OfflineCache.remove(key: "trainingActivity-\(scope)")
        }
        let data = try JSONEncoder().encode(WorkoutSessionListResponse(items: [], totalCount: 0, page: 1, pageSize: 50))
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200),
             request.url!.path.contains("/sessions") ? data : Data("[]".utf8))
        }
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        client.jwtToken = "test-token"
        let store = TrainingStreakStore(client: client, userId: scope)
        await store.load()
        let drills = DrillsViewModel(client: client, userId: scope, trainingStreakStore: store)
        drills.recommendations = [Fixtures.drill(title: "Cross-court Dinks")]
        if rawWorkout {
            drills.workout = WorkoutPlanResponse(
                warmup: nil, drills: [], cooldown: nil, totalDurationMinutes: nil,
                rawResponse: "Practice soft dinks for 15 minutes. Keep your paddle in front and reset between rallies."
            )
        }
        let auth = AuthViewModel(restoreSession: false)
        let tournaments = TournamentsViewModel(
            client: TournamentsAPIClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        )
        let root = view.environmentObject(auth).environmentObject(drills)
            .environmentObject(store).environmentObject(tournaments)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let original = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: root)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            original?.makeKeyAndVisible()
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        host.view.layoutIfNeeded()
        XCTAssertGreaterThan(host.view.bounds.width, 0)
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
