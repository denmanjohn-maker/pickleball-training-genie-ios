import SwiftUI

struct TournamentDetailView: View {
    @EnvironmentObject var viewModel: TournamentsViewModel
    @Environment(\.dismiss) private var dismiss
    let tournament: Tournament

    private var detail: TournamentDetail? {
        guard let detail = viewModel.selectedTournamentDetail, detail.id == tournament.id else { return nil }
        return detail
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    infoCard

                    if let registrationUrl = (detail?.registrationUrl ?? tournament.registrationUrl),
                       let url = URL(string: registrationUrl) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundColor(.pickleballGreen)
                                VStack(alignment: .leading) {
                                    Text("Register")
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

                    if let sourceURL = URL(string: tournament.sourceUrl) {
                        Link(destination: sourceURL) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                Text("View on \(tournament.source)")
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

                    statusSection
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.pickleballGreen)
                }
            }
            .task(id: tournament.id) {
                await viewModel.loadDetail(id: tournament.id)
            }
            .onDisappear {
                viewModel.clearDetail()
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.pickleballDarkGreen, Color.pickleballGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    CategoryBadge(category: tournament.source)
                    if tournament.isCanceled {
                        Text("CANCELED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.outRed)
                            .cornerRadius(8)
                    }
                }
                Text(tournament.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(TournamentDateFormatting.displayRange(startDate: tournament.startDate, endDate: tournament.endDate))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(20)
        }
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Details", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundColor(.pickleballDarkGreen)

            if let venueName = tournament.venueName {
                DetailRow(label: "Venue", value: venueName)
            }
            DetailRow(label: "Location", value: "\(tournament.city), \(tournament.state)")
            if let entryFee = tournament.entryFee {
                DetailRow(label: "Entry Fee", value: TournamentCurrencyFormatting.format(entryFee, currency: tournament.currency))
            }
        }
        .padding()
        .pickleballCard()
        .padding(.horizontal)
    }

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isLoadingDetail {
            ProgressView("Loading details…")
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
        } else if let error = viewModel.detailError {
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        } else if let related = detail?.relatedSourceListings, !related.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Also Listed On", systemImage: "square.on.square")
                    .font(.headline)
                    .foregroundColor(.pickleballDarkGreen)

                ForEach(related) { listing in
                    if let url = URL(string: listing.sourceUrl) {
                        Link(destination: url) {
                            HStack {
                                CategoryBadge(category: listing.source)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
            .pickleballCard()
            .padding(.horizontal)
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    TournamentDetailView(tournament: Tournament(
        id: 1,
        name: "Summer Kitchen Classic",
        startDate: "2026-08-12",
        endDate: "2026-08-14",
        venueName: "Riverside Courts",
        city: "Riverside",
        state: "CA",
        entryFee: 45,
        currency: "USD",
        registrationUrl: "https://example.com/register",
        source: "PickleballBrackets",
        sourceUrl: "https://example.com/tournament/1",
        isCanceled: false
    ))
    .environmentObject(TournamentsViewModel(
        client: TournamentsAPIClient(baseURL: URL(string: "http://localhost:5000/")!)
    ))
}
