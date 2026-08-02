import SwiftUI
import SafariServices

struct DrillDetailView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var favorites = FavoriteDrills.shared
    let drill: Drill
    @State private var completing = false
    @State private var showCompleteSuccess = false
    @State private var browserURL: BrowserURL?

    /// Identifiable wrapper so `.sheet(item:)` can present a tapped link.
    private struct BrowserURL: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }

    var isCompleted: Bool {
        drillsViewModel.completedDrillIds.contains(drill.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Banner
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [Color.cosmicPurple, Color.deepSpace],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 160)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                CategoryBadge(category: drill.category)
                                DUPRBadge(level: drill.targetDUPRLevel)
                            }
                            Text(drill.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .padding(20)
                    }
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Instructions", systemImage: "doc.text.fill")
                            .font(.headline)
                            .foregroundColor(.neonMagenta)

                        Text(drill.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .pickleballCard()
                    .padding(.horizontal)

                    // Video — opens in-app so the player doesn't lose their
                    // place mid-session.
                    if let videoUrl = drill.videoUrl, let url = URL(string: videoUrl) {
                        Button {
                            browserURL = BrowserURL(url: url)
                        } label: {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.neonCyan)
                                VStack(alignment: .leading) {
                                    Text("Watch Drill Video")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Plays right here in the app")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "play.circle")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .pickleballCard()
                        }
                        .padding(.horizontal)
                    }

                    // Source
                    if let sourceURL = URL(string: drill.sourceUrl) {
                        Button {
                            browserURL = BrowserURL(url: sourceURL)
                        } label: {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                Text("View Original Source")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.nebulaSurface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Complete Button
                    VStack(spacing: 12) {
                        if isCompleted {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.neonCyan)
                                Text("Drill Completed!")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.neonCyan)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.neonCyan.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            Button {
                                Task {
                                    completing = true
                                    await drillsViewModel.completeDrill(id: drill.id)
                                    completing = false
                                    showCompleteSuccess = true
                                }
                            } label: {
                                HStack {
                                    if completing {
                                        ProgressView().tint(.black)
                                    } else {
                                        Image(systemName: "checkmark.circle")
                                    }
                                    Text(completing ? "Marking Complete…" : "I Completed This Drill")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(completing)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.deepSpace)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        favorites.toggle(drill.id)
                    } label: {
                        Image(systemName: favorites.contains(drill.id) ? "heart.fill" : "heart")
                            .foregroundColor(.neonMagenta)
                    }
                    .accessibilityLabel(favorites.contains(drill.id) ? "Remove from favorites" : "Add to favorites")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.neonCyan)
                }
            }
            .sheet(item: $browserURL) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
            .alert("Great Work! 🏆", isPresented: $showCompleteSuccess) {
                Button("Keep Training!") {}
            } message: {
                Text("'\(drill.title)' has been marked as complete. Keep practicing to reach your DUPR goal!")
            }
        }
    }
}

/// In-app browser so drill videos and sources don't bounce the player out to
/// Safari. Handles YouTube links (which AVPlayer cannot).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(Color.neonMagenta)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

#Preview {
    DrillDetailView(drill: Drill(
        id: "1",
        title: "Dink Control Ladder",
        description: "Stand at the kitchen line and execute 20 consecutive cross-court dinks with a partner, focusing on soft touch and low net clearance.",
        targetDUPRLevel: 3.5,
        category: "Dinking",
        videoUrl: "https://youtube.com/watch?v=example",
        sourceUrl: "https://pickleballkitchen.com",
        createdAt: "2024-01-01"
    ))
    .environmentObject(DrillsViewModel(client: PickleballTrainingGenieClient(
        baseURL: URL(string: "http://localhost:5123/")!
    )))
}
