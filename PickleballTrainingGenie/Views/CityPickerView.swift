import SwiftUI

struct CityPickerView: View {
    @ObservedObject var viewModel: TournamentsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var displayedCities: [City] {
        if searchText.isEmpty { return viewModel.cities }
        return viewModel.cities.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.state.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingCities {
                    ProgressView("Loading cities…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tint(.neonVolt)
                } else if let error = viewModel.citiesError {
                    ContentUnavailableView {
                        Label("Could Not Load Cities", systemImage: "wifi.slash")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.loadCities() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.neonVolt)
                    }
                } else if displayedCities.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(displayedCities) { city in
                        Button {
                            Task {
                                await viewModel.selectCity(city)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(city.name), \(city.state)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("\(city.events1Month) in 1 month · \(city.events3Month) in 3 months")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if city.id == viewModel.selectedCity?.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.pickleballGreen)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Choose a City")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cities…")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.pickleballGreen)
                }
            }
            .task {
                if viewModel.cities.isEmpty {
                    await viewModel.loadCities()
                }
            }
        }
    }
}

#Preview {
    CityPickerView(viewModel: TournamentsViewModel(
        client: TournamentsAPIClient(baseURL: URL(string: "http://localhost:5000/")!)
    ))
}
