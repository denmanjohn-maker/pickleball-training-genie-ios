import SwiftUI

struct TournamentsListView: View {
    @EnvironmentObject var viewModel: TournamentsViewModel
    @State private var showCityPicker = false
    @State private var selectedTournament: Tournament?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Button {
                    showCityPicker = true
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.neonCyan)
                        Text(viewModel.selectedCity.map { "\($0.name), \($0.state)" } ?? "Choose a City")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.deepSpace)

                Divider()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TournamentWindow.allCases) { option in
                            FilterChip(
                                label: option.label,
                                isSelected: viewModel.window == option
                            ) {
                                Task { await viewModel.setWindow(option) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color.deepSpace)

                Divider()

                content
            }
            .navigationTitle("Tournaments")
            .navigationBarTitleDisplayMode(.large)
            .genieBrandIconToolbar()
            .sheet(isPresented: $showCityPicker) {
                CityPickerView(viewModel: viewModel)
            }
            .sheet(item: $selectedTournament) { tournament in
                TournamentDetailView(tournament: tournament)
                    .environmentObject(viewModel)
            }
            .task {
                if viewModel.cities.isEmpty {
                    await viewModel.loadCities()
                }
                if viewModel.selectedCity != nil, viewModel.tournaments.isEmpty {
                    await viewModel.loadTournaments(resetPage: true)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.selectedCity == nil {
            ContentUnavailableView {
                Label("Pick a Metro Area", systemImage: "mappin.and.ellipse")
            } description: {
                Text("Choose a city to see nearby tournaments within 100 miles.")
            } actions: {
                Button("Choose City") { showCityPicker = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.neonMagenta)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isLoadingTournaments && viewModel.tournaments.isEmpty {
            ProgressView("Loading tournaments…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tint(.neonMagenta)
        } else if let error = viewModel.tournamentsError {
            ContentUnavailableView {
                Label("Could Not Load Tournaments", systemImage: "wifi.slash")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.loadTournaments(resetPage: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.neonMagenta)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.tournaments.isEmpty {
            ContentUnavailableView {
                Label("No Tournaments Found", systemImage: "trophy")
            } description: {
                Text("No tournaments near \(viewModel.selectedCity?.name ?? "your area") in the next \(viewModel.window.label.lowercased()).")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(viewModel.tournaments) { tournament in
                    Button {
                        selectedTournament = tournament
                    } label: {
                        TournamentRowView(tournament: tournament)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                if viewModel.hasMorePages {
                    VStack(spacing: 6) {
                        if let error = viewModel.loadMoreError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        HStack {
                            Spacer()
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .tint(.neonMagenta)
                            } else {
                                Button("Load More") {
                                    Task { await viewModel.loadMoreTournaments() }
                                }
                                .foregroundColor(.neonCyan)
                            }
                            Spacer()
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.deepSpace)
        }
    }
}

struct TournamentRowView: View {
    let tournament: Tournament

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tournament.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(TournamentDateFormatting.displayRange(startDate: tournament.startDate, endDate: tournament.endDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if tournament.isCanceled {
                    Text("CANCELED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.cometRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cometRed.opacity(0.12))
                        .cornerRadius(8)
                }
            }

            if let venueName = tournament.venueName {
                Text("\(venueName) · \(tournament.city), \(tournament.state)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("\(tournament.city), \(tournament.state)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 6) {
                CategoryBadge(category: tournament.source)
                if let feeText = formattedEntryFee {
                    Text(feeText)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.cosmicPurple)
                }
            }
        }
        .padding()
        .pickleballCard()
    }

    private var formattedEntryFee: String? {
        guard let entryFee = tournament.entryFee else { return nil }
        return TournamentCurrencyFormatting.format(entryFee, currency: tournament.currency)
    }
}

#Preview {
    TournamentsListView()
        .environmentObject(TournamentsViewModel(
            client: TournamentsAPIClient(baseURL: URL(string: "http://localhost:5000/")!)
        ))
}
