import SwiftUI
import PhotosUI

/// Stepped profile-completion flow shown right after account creation (email,
/// Google, or Apple) until the required profile fields are filled in.
struct OnboardingFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            SynthwaveGradient()
            StarFieldView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 24) {
                        stepContent
                            .padding(24)
                            .background(Color.nebulaSurface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.neonMagenta.opacity(0.55), .neonCyan.opacity(0.55)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .padding(.horizontal, 20)

                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 24)
                        }

                        navigationButtons
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }
                    .padding(.top, 12)
                    .readableWidth()
                }
            }
        }
        .task {
            viewModel.prefill(from: authViewModel.currentUser)
            await viewModel.loadCities()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text("Set Up Your Profile")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.neonMagenta, .neonCyan], startPoint: .leading, endPoint: .trailing)
                )
                .padding(.top, 16)

            HStack(spacing: 8) {
                ForEach(OnboardingViewModel.Step.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= viewModel.step.rawValue ? Color.neonMagenta : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)

            Text(viewModel.step.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .name: NameZipStepView(viewModel: viewModel)
        case .ratings: RatingsStepView(viewModel: viewModel)
        case .preferences: PreferencesStepView(viewModel: viewModel)
        case .avatar: AvatarStepView(viewModel: viewModel)
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if viewModel.step != .name {
                Button {
                    withAnimation { viewModel.goBack() }
                } label: {
                    Text("Back")
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 100)
            }

            if viewModel.step == .avatar {
                Button {
                    Task { await viewModel.submit(authViewModel: authViewModel) }
                } label: {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.black)
                        }
                        Text(viewModel.isSubmitting ? "Saving…" : "Let's Play! 🎾")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isSubmitting)
            } else {
                Button {
                    withAnimation { viewModel.advance() }
                } label: {
                    Text("Continue")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!stepValid)
            }
        }
    }

    private var stepValid: Bool {
        switch viewModel.step {
        case .name: return viewModel.nameStepValid
        case .ratings: return viewModel.targetValid
        case .preferences, .avatar: return true
        }
    }
}

// MARK: - Step 1: Name + Zip

private struct NameZipStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showCityPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingField(icon: "person.fill", title: "First Name") {
                TextField("First name", text: $viewModel.firstName)
                    .textContentType(.givenName)
            }

            OnboardingField(icon: "person.fill", title: "Last Name") {
                TextField("Last name", text: $viewModel.lastName)
                    .textContentType(.familyName)
            }

            OnboardingField(icon: "mappin.and.ellipse", title: "Zip Code") {
                TextField("e.g. 75201", text: $viewModel.zipCode)
                    .keyboardType(.numberPad)
                    .textContentType(.postalCode)
            }

            if viewModel.zipValid {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Your Tournament City", systemImage: "trophy.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.neonCyan)

                    if viewModel.isLoadingCities {
                        HStack(spacing: 10) {
                            ProgressView().tint(.neonMagenta)
                            Text("Finding the closest tournament city…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if let city = viewModel.matchedCity {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(city.name), \(city.state)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("We'll show you tournaments near here")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Change") { showCityPicker = true }
                                .font(.caption)
                                .foregroundColor(.neonMagenta)
                        }
                        .padding(12)
                        .background(Color.neonCyan.opacity(0.08))
                        .cornerRadius(10)
                    } else if let error = viewModel.citiesError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .sheet(isPresented: $showCityPicker) {
            OnboardingCityPicker(viewModel: viewModel)
        }
    }
}

private struct OnboardingCityPicker: View {
    @ObservedObject var viewModel: OnboardingViewModel
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
            List(displayedCities) { city in
                Button {
                    viewModel.selectCity(city)
                    dismiss()
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
                        if city.id == viewModel.matchedCity?.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.neonCyan)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.deepSpace)
            .navigationTitle("Choose a City")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search cities…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonCyan)
                }
            }
        }
    }
}

// MARK: - Step 2: DUPR Ratings

private struct RatingsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showSkillCheck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Your DUPR Level", systemImage: "chart.bar.fill")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.neonCyan)

            Text("Don't have an official DUPR rating? Pick your best guess — you can change it anytime.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button {
                showSkillCheck = true
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                    Text("Not sure? Take the 60-second skill check")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .font(.subheadline)
                .foregroundColor(.neonMagenta)
                .padding(12)
                .background(Color.neonMagenta.opacity(0.1))
                .cornerRadius(10)
            }
            .sheet(isPresented: $showSkillCheck) {
                SkillAssessmentView { result in
                    viewModel.apply(assessment: result)
                    showSkillCheck = false
                }
            }

            duprPicker(title: "Singles DUPR", selection: $viewModel.singlesDUPR)
            duprPicker(title: "Doubles DUPR", selection: $viewModel.doublesDUPR)
            duprPicker(title: "Target DUPR (your goal)", selection: $viewModel.targetDUPR)

            if !viewModel.targetValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Target must be ≥ current DUPR")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    private func duprPicker(title: String, selection: Binding<Decimal>) -> some View {
        SkillLevelPicker(title: title, selection: selection)
    }
}

/// Segmented level picker that scales to the full 2.0–5.0 range: numeric
/// segments, with the selected tier's plain-language name underneath.
struct SkillLevelPicker: View {
    let title: String
    @Binding var selection: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Picker(title, selection: $selection) {
                ForEach(SkillLevel.allCases) { level in
                    Text(level.shortLabel).tag(level.value)
                }
            }
            .pickerStyle(.segmented)
            Text(SkillLevel.nearest(to: selection).name)
                .font(.caption2)
                .foregroundColor(SkillLevel.nearest(to: selection).color)
        }
    }
}

// MARK: - Step 3: Preferences (all optional)

private struct PreferencesStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Optional — these help the genie tailor your workouts.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Label("Preferred Session Length", systemImage: "timer")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Picker("Session Length", selection: $viewModel.sessionDuration) {
                    ForEach([15, 30, 45, 60], id: \.self) { minutes in
                        Text("\(minutes)m").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Dominant Hand", systemImage: "hand.raised.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Picker("Dominant Hand", selection: $viewModel.dominantHand) {
                    Text("Right").tag("right")
                    Text("Left").tag("left")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Play Style", systemImage: "person.2.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Picker("Play Style", selection: $viewModel.playStyle) {
                    Text("Singles").tag("singles")
                    Text("Doubles").tag("doubles")
                    Text("Both").tag("both")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Years Playing", systemImage: "calendar")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Stepper(value: $viewModel.yearsPlaying, in: 0...50) {
                    Text(viewModel.yearsPlaying == 0
                         ? "Less than a year"
                         : "\(viewModel.yearsPlaying) year\(viewModel.yearsPlaying == 1 ? "" : "s")")
                        .font(.subheadline)
                }
            }
        }
    }
}

// MARK: - Step 4: Avatar

struct AvatarStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var photoItem: PhotosPickerItem?

    private let columns = [GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 14)]

    var body: some View {
        VStack(spacing: 20) {
            // Live preview of the current choice
            if let image = viewModel.customPhotoImage {
                AvatarView(avatarId: "custom", customImage: image, size: 110)
            } else if let avatar = viewModel.selectedAvatar {
                AvatarView(avatarId: avatar.avatarId, size: 110)
            } else {
                AvatarView(avatarId: nil, size: 110)
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(BuiltInAvatar.allCases) { avatar in
                    Button {
                        viewModel.selectedAvatar = avatar
                        viewModel.customPhotoData = nil
                        viewModel.customPhotoImage = nil
                        photoItem = nil
                    } label: {
                        VStack(spacing: 4) {
                            BuiltInAvatarView(avatar: avatar, size: 60)
                                .overlay(
                                    Circle().strokeBorder(
                                        isSelected(avatar) ? Color.neonCyan : Color.clear,
                                        lineWidth: 3
                                    )
                                )
                            Text(avatar.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(isSelected(avatar) ? .neonCyan : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }

            let photoButtonTitle = viewModel.customPhotoImage == nil ? "Use a Photo Instead" : "Choose a Different Photo"
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(photoButtonTitle)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.neonMagenta)
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let jpegData = image.avatarJPEGData() {
                        viewModel.customPhotoData = jpegData
                        viewModel.customPhotoImage = UIImage(data: jpegData)
                        viewModel.selectedAvatar = nil
                    }
                }
            }
        }
    }

    private func isSelected(_ avatar: BuiltInAvatar) -> Bool {
        viewModel.customPhotoImage == nil && viewModel.selectedAvatar == avatar
    }
}

// MARK: - Shared field styling

private struct OnboardingField<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AuthViewModel())
}
