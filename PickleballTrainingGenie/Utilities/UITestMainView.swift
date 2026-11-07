#if DEBUG
    import SwiftUI

    /// An isolated fixture transport for UI tests; never contacts a backend or
    /// writes credentials. This entry point is excluded from release builds.
    struct UITestMainView: View {
        @Environment(\.horizontalSizeClass) private var nativeSizeClass
        @State private var alternateLayout = false
        @StateObject private var auth = AuthViewModel(restoreSession: false)
        @StateObject private var drills: DrillsViewModel
        @StateObject private var activity: TrainingStreakStore
        @StateObject private var tournaments: TournamentsViewModel

        init() {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [UITestURLProtocol.self]
            let session = URLSession(configuration: configuration)
            let url = URL(string: "https://ui-fixture.invalid/")!
            let client = PickleballTrainingGenieClient(baseURL: url, session: session)
            client.jwtToken = "fixture-only"
            let scope = "ui-fixture-\(UUID().uuidString)"
            let activity = TrainingStreakStore(client: client, userId: scope)
            let drills = DrillsViewModel(client: client, userId: scope, trainingStreakStore: activity)
            if ProcessInfo.processInfo.environment["GENIE_UI_WORKOUT"] == "1" {
                drills.workout = WorkoutPlanResponse(
                    warmup: nil, drills: [], cooldown: nil, totalDurationMinutes: nil,
                    rawResponse: "Fixture saved plan: practice soft dinks for fifteen minutes."
                )
            } else if ProcessInfo.processInfo.environment["GENIE_UI_WORKOUT"] == "structured" {
                drills.workout = WorkoutPlanResponse(
                    warmup: nil,
                    drills: [
                        WorkoutDrillItem(
                            title: "Fixture Workout Dinks", category: "Dinking", durationMinutes: 5,
                            coachingNotes: "Keep your paddle in front."
                        )
                    ],
                    cooldown: nil, totalDurationMinutes: 5, rawResponse: nil
                )
            }
            _drills = StateObject(wrappedValue: drills)
            _activity = StateObject(wrappedValue: activity)
            _tournaments = StateObject(
                wrappedValue: TournamentsViewModel(
                    client: TournamentsAPIClient(baseURL: url, session: session)
                ))
        }

        var body: some View {
            MainTabView()
                .environmentObject(auth)
                .environmentObject(drills)
                .environmentObject(activity)
                .environmentObject(tournaments)
                .environment(\.horizontalSizeClass, alternateLayout
                             ? (nativeSizeClass == .regular ? .compact : .regular)
                             : nativeSizeClass)
                .safeAreaInset(edge: .bottom) {
                    if ProcessInfo.processInfo.environment["GENIE_UI_SIZE_TEST"] == "1" {
                        Button("Toggle Test Size Class") { alternateLayout.toggle() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
        }
    }

    private final class UITestURLProtocol: URLProtocol {
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            let path = request.url!.path.lowercased()
            let json: String
            if path.contains("/sessions") {
                json = #"{"items":[],"totalCount":0,"page":1,"pageSize":50}"#
            } else if path.contains("recommend") {
                json = "[]"
            } else if path.contains("drills") && !path.contains("progress") {
                json =
                    #"[{"id":"fixture-dink","title":"Fixture Dink Rally","description":"Keep a soft cross-court rally going.","targetDUPRLevel":3,"category":"Dinking","sourceUrl":"https://ui-fixture.invalid/drill","createdAt":"2026-01-01T00:00:00Z"}]"#
            } else if path.contains("cities") {
                json = #"[{"id":1,"name":"Fixture City","state":"TX","zip":"75201","events1Month":1,"events3Month":1}]"#
            } else {
                json = "[]"
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
#endif
