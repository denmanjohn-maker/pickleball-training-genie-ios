import SwiftUI

/// The 60-second skill check: one plain-language question per screen, then a
/// result card with an estimated level and focus areas. The caller receives
/// the result via `onComplete` (the view saves it locally itself).
struct SkillAssessmentView: View {
    let onComplete: (AssessmentResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var questionIndex = 0
    @State private var answers: [Int: AssessmentQuestion.Answer] = [:]
    @State private var result: AssessmentResult?

    private var questions: [AssessmentQuestion] { SkillAssessment.questions }

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    ResultView(result: result) {
                        onComplete(result)
                    }
                } else {
                    questionScreen
                }
            }
            .background(Color.deepSpace)
            .navigationTitle("Skill Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonCyan)
                }
            }
        }
    }

    private var questionScreen: some View {
        let question = questions[questionIndex]
        return VStack(spacing: 24) {
            ProgressView(value: Double(questionIndex + 1), total: Double(questions.count))
                .tint(.neonMagenta)
                .padding(.horizontal)

            Text("Question \(questionIndex + 1) of \(questions.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Text(question.prompt)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                if let detail = question.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .pickleballCard()
            .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(AssessmentQuestion.Answer.allCases.reversed(), id: \.rawValue) { answer in
                    Button {
                        select(answer, for: question)
                    } label: {
                        Text(answer.label)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
            .padding(.horizontal)

            if questionIndex > 0 {
                Button {
                    questionIndex -= 1
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.top)
    }

    private func select(_ answer: AssessmentQuestion.Answer, for question: AssessmentQuestion) {
        answers[question.id] = answer
        if questionIndex + 1 < questions.count {
            withAnimation(.snappy) { questionIndex += 1 }
        } else {
            let scored = SkillAssessment.score(answers: answers)
            SkillAssessment.save(scored)
            withAnimation(.snappy) { result = scored }
        }
    }
}

// MARK: - Result screen

private struct ResultView: View {
    let result: AssessmentResult
    let onUseLevel: () -> Void

    private var level: SkillLevel { result.estimatedSkillLevel }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(level.color.opacity(0.15))
                            .frame(width: 84, height: 84)
                        Text(level.shortLabel)
                            .font(.ecStatValue)
                            .foregroundColor(level.color)
                    }
                    Text(level.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(level.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .pickleballCard()

                if !result.focusCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Work on these first", systemImage: "target")
                            .font(.headline)
                            .foregroundColor(.starlight)
                        ForEach(result.focusCategories, id: \.self) { category in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .foregroundColor(.neonMagenta)
                                Text(category)
                                    .font(.subheadline)
                            }
                        }
                        Text("Your recommendations will lead with drills for these skills.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .pickleballCard()
                }

                Button {
                    onUseLevel()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Use \(level.shortLabel) as My Level")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Text("Just an estimate — you can adjust your ratings anytime.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    SkillAssessmentView { _ in }
}
