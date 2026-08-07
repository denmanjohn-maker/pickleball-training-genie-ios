import SwiftUI
import PhotosUI

/// Form-based profile editing from the Profile tab: name, zip/home city,
/// and playing preferences. Ratings keep their own dedicated editor.
struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var zipCode = ""
    @State private var matchedCity: City?
    @State private var cities: [City] = []
    @State private var sessionDuration = 30
    @State private var dominantHand = "right"
    @State private var playStyle = "both"
    @State private var yearsPlaying = 1

    private let tournamentsClient = TournamentsAPIClient(baseURL: URL(string: TournamentsAPIConfig.baseURL)!)

    private var zipValid: Bool { ZipCityMatcher.isValidZip(zipCode) }
    private var formValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && zipValid
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
            }

            Section {
                TextField("Zip code", text: $zipCode)
                    .keyboardType(.numberPad)
                    .onChange(of: zipCode) { _, newValue in
                        if newValue.count > 5 { zipCode = String(newValue.prefix(5)) }
                        rematchCity()
                    }
                if let city = matchedCity {
                    HStack {
                        Label("\(city.name), \(city.state)", systemImage: "trophy.fill")
                            .font(.subheadline)
                            .foregroundColor(.neonCyan)
                        Spacer()
                    }
                }
            } header: {
                Text("Location")
            } footer: {
                Text("Your zip code picks the closest city with tournament data.")
            }

            Section("Preferences") {
                Picker("Session Length", selection: $sessionDuration) {
                    ForEach([15, 30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                }
                Picker("Dominant Hand", selection: $dominantHand) {
                    Text("Right").tag("right")
                    Text("Left").tag("left")
                }
                Picker("Play Style", selection: $playStyle) {
                    Text("Singles").tag("singles")
                    Text("Doubles").tag("doubles")
                    Text("Both").tag("both")
                }
                Stepper(value: $yearsPlaying, in: 0...50) {
                    Text(yearsPlaying == 0 ? "Playing less than a year" : "Playing \(yearsPlaying) year\(yearsPlaying == 1 ? "" : "s")")
                }
            }

            if let error = authViewModel.errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if authViewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Save Profile").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(authViewModel.isLoading || !formValid)
                .listRowBackground(Color.neonMagenta)
                .foregroundColor(.black)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.deepSpace)
        .onAppear(perform: populate)
        .task {
            if cities.isEmpty {
                cities = (try? await tournamentsClient.cities()) ?? []
                rematchCity(keepExisting: true)
            }
        }
    }

    private func populate() {
        guard let user = authViewModel.currentUser else { return }
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        zipCode = user.zipCode ?? ""
        sessionDuration = user.preferredSessionDurationMinutes ?? 30
        dominantHand = user.dominantHand ?? "right"
        playStyle = user.preferredPlayStyle ?? "both"
        yearsPlaying = user.yearsPlaying ?? 1
    }

    private func rematchCity(keepExisting: Bool = false) {
        guard zipValid, !cities.isEmpty else { return }
        if keepExisting,
           let existingId = authViewModel.currentUser?.homeCityId,
           zipCode == authViewModel.currentUser?.zipCode,
           let existing = cities.first(where: { $0.id == existingId }) {
            matchedCity = existing
            return
        }
        matchedCity = ZipCityMatcher.closestCity(toZip: zipCode, in: cities)
    }

    private func save() async {
        authViewModel.errorMessage = nil
        let request = UpdateProfileRequest(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            zipCode: zipCode,
            homeCityId: matchedCity?.id,
            homeCityName: matchedCity.map { "\($0.name), \($0.state)" },
            dominantHand: dominantHand,
            yearsPlaying: yearsPlaying,
            preferredPlayStyle: playStyle,
            preferredSessionDurationMinutes: sessionDuration
        )
        let success = await authViewModel.updateProfile(request)
        if success {
            if let city = matchedCity {
                UserDefaults.standard.set(city.id, forKey: "tournaments.lastCityId")
            }
            dismiss()
        }
    }
}

/// Avatar selection sheet: built-in pickleball avatars or a photo-library photo.
/// Changes save immediately.
struct AvatarPickerSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var isSaving = false

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 16)]

    private var currentAvatarId: String? { authViewModel.currentUser?.avatarId }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                AvatarView(
                    avatarId: currentAvatarId,
                    customImage: authViewModel.avatarImage,
                    size: 110
                )
                .padding(.top, 20)

                if isSaving {
                    ProgressView().tint(.neonMagenta)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(BuiltInAvatar.allCases) { avatar in
                        Button {
                            Task { await select(avatar) }
                        } label: {
                            VStack(spacing: 4) {
                                BuiltInAvatarView(avatar: avatar, size: 64)
                                    .overlay(
                                        Circle().strokeBorder(
                                            currentAvatarId == avatar.avatarId ? Color.neonCyan : Color.clear,
                                            lineWidth: 3
                                        )
                                    )
                                Text(avatar.displayName)
                                    .font(.system(size: 9))
                                    .foregroundColor(currentAvatarId == avatar.avatarId ? .neonCyan : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal)
                .readableWidth(max: 600)

                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Use a Photo from Your Library")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.neonMagenta)
                }
                .disabled(isSaving)
                .onChange(of: photoItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await uploadPhoto(newItem) }
                }

                if let error = authViewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.deepSpace)
    }

    private func select(_ avatar: BuiltInAvatar) async {
        authViewModel.errorMessage = nil
        isSaving = true
        let success = await authViewModel.updateProfile(UpdateProfileRequest(avatarId: avatar.avatarId))
        isSaving = false
        if success { dismiss() }
    }

    private func uploadPhoto(_ item: PhotosPickerItem) async {
        authViewModel.errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpegData = image.avatarJPEGData() else {
            authViewModel.errorMessage = "Couldn't read that photo. Try a different one."
            return
        }
        let success = await authViewModel.uploadAvatarPhoto(jpegData)
        if success { dismiss() }
    }
}
