import SwiftUI

struct DrillDetailView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @Environment(\.dismiss) private var dismiss
    let drill: Drill
    @State private var completing = false
    @State private var showCompleteSuccess = false

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
                            colors: [Color.pickleballDarkGreen, Color.pickleballGreen],
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
                            .foregroundColor(.pickleballDarkGreen)

                        Text(drill.description)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .pickleballCard()
                    .padding(.horizontal)

                    // Video Link
                    if let videoUrl = drill.videoUrl, let url = URL(string: videoUrl) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title3)
                                    .foregroundColor(.pickleballGreen)
                                VStack(alignment: .leading) {
                                    Text("Watch Drill Video")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text("Tap to open in browser")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .pickleballCard()
                        }
                        .padding(.horizontal)
                    }

                    // Source Link
                    if let sourceURL = URL(string: drill.sourceUrl) {
                        Link(destination: sourceURL) {
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
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Complete Button
                    VStack(spacing: 12) {
                        if isCompleted {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.pickleballGreen)
                                Text("Drill Completed!")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.pickleballGreen)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pickleballGreen.opacity(0.1))
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.pickleballGreen)
                }
            }
            .alert("Great Work! 🏆", isPresented: $showCompleteSuccess) {
                Button("Keep Training!") {}
            } message: {
                Text("'\(drill.title)' has been marked as complete. Keep practicing to reach your DUPR goal!")
            }
        }
    }
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
