import SwiftUI

// MARK: - Models

/// Bundled rules-and-fundamentals content, decoded from
/// `Resources/LearnContent.json` (same pattern as `ZipPrefixCentroids.json`).
/// Fully offline by design — a beginner at a court with no signal can still
/// look up the kitchen rule.
struct LearnContent: Decodable {
    struct Topic: Decodable, Identifiable {
        struct Section: Decodable {
            let heading: String
            let body: String
        }

        let id: String
        let title: String
        let icon: String
        let summary: String
        let sections: [Section]
    }

    struct GlossaryEntry: Decodable, Identifiable {
        let term: String
        let definition: String

        var id: String { term }
    }

    let topics: [Topic]
    let glossary: [GlossaryEntry]

    static let bundled: LearnContent = {
        guard let url = Bundle.main.url(forResource: "LearnContent", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let content = try? JSONDecoder().decode(LearnContent.self, from: data)
        else {
            // A missing or malformed bundle resource is a packaging bug —
            // fail loudly in debug builds instead of shipping an empty screen.
            assertionFailure("LearnContent.json is missing from the bundle or failed to decode")
            return LearnContent(topics: [], glossary: [])
        }
        return content
    }()
}

// MARK: - Topic list

/// Rules and fundamentals for players who are new to the game. Pushed from
/// the Drills tab toolbar.
struct LearnView: View {
    private let content = LearnContent.bundled

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("New to pickleball?")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Everything you need to walk onto a court with confidence — no signal required.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)

                ForEach(content.topics) { topic in
                    NavigationLink {
                        LearnTopicView(topic: topic)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: topic.icon)
                                .font(.title3)
                                .foregroundColor(.neonCyan)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(topic.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text(topic.summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .pickleballCard()
                    }
                }

                if !content.glossary.isEmpty {
                    NavigationLink {
                        GlossaryView(entries: content.glossary)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "character.book.closed.fill")
                                .font(.title3)
                                .foregroundColor(.solarGold)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Glossary")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("Dinks, Ernes, ATPs — what everyone at the court is talking about.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .pickleballCard()
                    }
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color.deepSpace)
        .navigationTitle("Learn")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Topic detail

private struct LearnTopicView: View {
    let topic: LearnContent.Topic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .font(.title2)
                        .foregroundColor(.neonCyan)
                    Text(topic.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .pickleballCard()

                ForEach(topic.sections, id: \.heading) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(.headline)
                            .foregroundColor(.starlight)
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pickleballCard()
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color.deepSpace)
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Glossary

private struct GlossaryView: View {
    let entries: [LearnContent.GlossaryEntry]
    @State private var searchText = ""

    private var filtered: [LearnContent.GlossaryEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter {
            $0.term.localizedCaseInsensitiveContains(searchText)
                || $0.definition.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(filtered) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.term)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.neonCyan)
                        Text(entry.definition)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pickleballCard()
                }
            }
            .padding()
            .readableWidth()
        }
        .background(Color.deepSpace)
        .navigationTitle("Glossary")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search terms…")
    }
}

#Preview {
    NavigationStack { LearnView() }
}
