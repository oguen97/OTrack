import SwiftUI

private struct LoggedMealEntry: Identifiable {
    let id = UUID()
    let meal: MealItem
    let addedAt: Date
}

struct ContentView: View {
    @State private var loggedMeals: [LoggedMealEntry] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                TodayView(
                    loggedMeals: loggedMeals,
                    onAddMeals: { newMeals in
                    let timestamp = Date()
                    loggedMeals.append(
                        contentsOf: newMeals.map {
                            LoggedMealEntry(meal: $0, addedAt: timestamp)
                        }
                    )
                    },
                    onDeleteMeal: { entry in
                        loggedMeals.removeAll { $0.id == entry.id }
                    }
                )
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeals: [MealItem] = []

    private let meals = SampleMeals.items
    let onDone: ([MealItem]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 28) {
                Text("Add Meal")
                    .font(.system(size: 34, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                searchBar
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(meals) { meal in
                        NavigationLink {
                            MealDetailView(meal: meal) { scaledMeal in
                                selectedMeals.append(scaledMeal)
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Text(meal.name)
                                    .font(.title3)
                                    .foregroundStyle(.black)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.white.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.035), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.012), radius: 2, x: 0, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground).opacity(0),
                        Color(.systemGroupedBackground).opacity(0.92),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 16)

                Button {
                    onDone(selectedMeals)
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Text("Done")
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .padding(.horizontal, 18)
                            .foregroundStyle(.black)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
                            )

                        if addedMealsCount > 0 {
                            Text("\(addedMealsCount)")
                                .font(.title3)
                                .frame(width: 56, height: 56)
                                .foregroundStyle(.black)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 0)
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private var addedMealsCount: Int {
        selectedMeals.count
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
            Text("Search")
                .font(.title3)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct TodayView: View {
    let loggedMeals: [LoggedMealEntry]
    let onAddMeals: ([MealItem]) -> Void
    let onDeleteMeal: (LoggedMealEntry) -> Void

    private let caloriesGoal = 2700
    private let carbsGoal = 250
    private let proteinGoal = 150
    private let fatsGoal = 80

    private var totalCalories: Int {
        loggedMeals.reduce(0) { $0 + $1.meal.calories }
    }

    private var totalCarbs: Int {
        loggedMeals.reduce(0) { $0 + $1.meal.carbs }
    }

    private var totalProtein: Int {
        loggedMeals.reduce(0) { $0 + $1.meal.protein }
    }

    private var totalFats: Int {
        loggedMeals.reduce(0) { $0 + $1.meal.fats }
    }

    private var remainingCalories: Int {
        caloriesGoal - totalCalories
    }

    private var displayedCaloriesValue: Int {
        remainingCalories < 0 ? abs(remainingCalories) : remainingCalories
    }

    private var caloriesProgress: CGFloat {
        CGFloat(totalCalories) / CGFloat(caloriesGoal)
    }

    private var carbsProgress: CGFloat {
        CGFloat(totalCarbs) / CGFloat(carbsGoal)
    }

    private var proteinProgress: CGFloat {
        CGFloat(totalProtein) / CGFloat(proteinGoal)
    }

    private var fatsProgress: CGFloat {
        CGFloat(totalFats) / CGFloat(fatsGoal)
    }

    private var caloriesSubtitle: String {
        remainingCalories < 0 ? "Over" : "Remaining"
    }

    private var caloriesStatusColor: Color {
        remainingCalories < 0 ? .red : .black
    }

    private var caloriesFillColor: Color {
        remainingCalories < 0 ? .red : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom) {
                    Text("Today")
                        .font(.system(size: 36, weight: .medium))
                    Spacer()
                    Text("01.01.26")
                        .font(.title3)
                }

                SummaryCard(
                    title: "Calories",
                    valueText: "\(displayedCaloriesValue)",
                    subtitle: caloriesSubtitle,
                    valueColor: caloriesStatusColor,
                    subtitleColor: caloriesStatusColor,
                    topSectionProgress: caloriesProgress,
                    topSectionFillColor: caloriesFillColor,
                    macros: [
                        MacroStat(
                            title: "Carbs",
                            value: "\(totalCarbs) / \(carbsGoal)",
                            progress: carbsProgress,
                            fillColor: .brown
                        ),
                        MacroStat(
                            title: "Protein",
                            value: "\(totalProtein) / \(proteinGoal)",
                            progress: proteinProgress,
                            fillColor: .orange
                        ),
                        MacroStat(
                            title: "Fats",
                            value: "\(totalFats) / \(fatsGoal)",
                            progress: fatsProgress,
                            fillColor: .yellow
                        )
                    ]
                )
                .padding(.bottom, loggedMeals.isEmpty ? 0 : 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if !loggedMeals.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("My Meals")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(loggedMeals) { entry in
                                LoggedMealRow(
                                    entry: entry,
                                    timeText: timeString(for: entry.addedAt),
                                    onDelete: {
                                        onDeleteMeal(entry)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(.systemGroupedBackground).opacity(0),
                        Color(.systemGroupedBackground).opacity(0.92),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 16)

                NavigationLink {
                    AddMealView(onDone: onAddMeals)
                } label: {
                    Text("Add Meal")
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .padding(.horizontal, 18)
                        .foregroundStyle(.black)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                .background(Color(.systemGroupedBackground))
            }
        }
    }

    private func timeString(for date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private struct LoggedMealRow: View {
    let entry: LoggedMealEntry
    let timeText: String
    let onDelete: () -> Void

    @State private var horizontalOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let fadeThreshold = proxy.size.width * 0.25
            let deleteThreshold = proxy.size.width * 0.5
            let deleteProgress = min(abs(horizontalOffset) / fadeThreshold, 1)

            ZStack {
                HStack(spacing: 0) {
                    Text(entry.meal.name)
                        .font(.title3)
                        .foregroundStyle(Color.black.opacity(1 - deleteProgress))
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Rectangle()
                        .fill(Color.black.opacity(0.05 * (1 - deleteProgress)))
                        .frame(width: 1, height: 32)

                    Text(timeText)
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.7 * (1 - deleteProgress)))
                        .frame(width: 72)
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background {
                    Color.white.opacity(0.5)
                    Color.red.opacity(0.38 * deleteProgress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.035), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.012), radius: 2, x: 0, y: 1)
                .offset(x: horizontalOffset)

                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(Color.white.opacity(deleteProgress))
                    .offset(x: horizontalOffset)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        horizontalOffset = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        let shouldDelete = abs(value.translation.width) > deleteThreshold

                        if shouldDelete {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                horizontalOffset = -proxy.size.width
                            }
                            onDelete()
                        } else {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                horizontalOffset = 0
                            }
                        }
                    }
            )
        }
        .frame(height: 56)
    }
}

private struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gramsText = "100"

    let meal: MealItem
    let onAdd: (MealItem) -> Void

    private var gramsValue: Int {
        max(Int(gramsText) ?? 0, 0)
    }

    private var scaleFactor: Double {
        Double(gramsValue) / 100
    }

    private var scaledMeal: MealItem {
        MealItem(
            name: meal.name,
            calories: scaledValue(meal.calories),
            carbs: scaledValue(meal.carbs),
            protein: scaledValue(meal.protein),
            fats: scaledValue(meal.fats)
        )
    }

    var body: some View {
        VStack(spacing: 32) {
            Text(meal.name)
                .font(.system(size: 34, weight: .medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            SummaryCard(
                title: "Calories",
                valueText: "\(scaledMeal.calories)",
                subtitle: nil,
                topSectionProgress: 1,
                topSectionFillColor: .green,
                macros: [
                    MacroStat(title: "Carbs", value: "\(scaledMeal.carbs)", progress: 1, fillColor: .brown),
                    MacroStat(title: "Protein", value: "\(scaledMeal.protein)", progress: 1, fillColor: .orange),
                    MacroStat(title: "Fats", value: "\(scaledMeal.fats)", progress: 1, fillColor: .yellow)
                ]
            )

            HStack(spacing: 0) {
                Button {
                    onAdd(scaledMeal)
                    dismiss()
                } label: {
                    Text("+")
                        .font(.title2)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.black)
                }

                TextField("100", text: $gramsText)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .frame(width: 140, height: 64)
                    .foregroundStyle(.black)
                    .onChange(of: gramsText) { _, newValue in
                        let filteredValue = newValue.filter(\.isNumber)
                        if filteredValue != newValue {
                            gramsText = filteredValue
                        }
                    }

                Text("g")
                    .font(.title2)
                    .frame(width: 96, height: 64)
                    .foregroundStyle(.black)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .overlay {
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: 64)
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1)
                    Spacer()
                        .frame(width: 140)
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1)
                    Spacer()
                        .frame(width: 96)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private func scaledValue(_ value: Int) -> Int {
        Int((Double(value) * scaleFactor).rounded())
    }
}

private struct MacroStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let progress: CGFloat
    let fillColor: Color
}

private struct SummaryCard: View {
    let title: String
    let valueText: String
    let subtitle: String?
    let valueColor: Color
    let subtitleColor: Color
    let topSectionProgress: CGFloat
    let topSectionFillColor: Color
    let macros: [MacroStat]

    init(
        title: String,
        valueText: String,
        subtitle: String?,
        valueColor: Color = .black,
        subtitleColor: Color = .black,
        topSectionProgress: CGFloat = 0,
        topSectionFillColor: Color = .green,
        macros: [MacroStat]
    ) {
        self.title = title
        self.valueText = valueText
        self.subtitle = subtitle
        self.valueColor = valueColor
        self.subtitleColor = subtitleColor
        self.topSectionProgress = topSectionProgress
        self.topSectionFillColor = topSectionFillColor
        self.macros = macros
    }

    private var topSectionHeight: CGFloat {
        subtitle == nil ? 150 : 170
    }

    private var macroSectionHeight: CGFloat {
        subtitle == nil ? 82 : 92
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                VStack(spacing: 8) {
                    Text(valueText)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(valueColor)
                    if let subtitle {
                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(subtitleColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: topSectionHeight)
            .background {
                ProgressFillBackground(
                    progress: topSectionProgress,
                    fillColor: topSectionFillColor
                )
            }

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.black.opacity(0.12))

            HStack(spacing: 0) {
                ForEach(Array(macros.enumerated()), id: \.element.id) { index, macro in
                    VStack(spacing: 0) {
                        Text(macro.title)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(macro.value)
                            .font(.system(size: 20, weight: .medium))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: macroSectionHeight,
                        maxHeight: macroSectionHeight,
                        alignment: .topLeading
                    )
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background {
                        ProgressFillBackground(
                            progress: macro.progress,
                            fillColor: macro.fillColor
                        )
                    }

                    if index < macros.count - 1 {
                        Rectangle()
                            .frame(width: 1)
                            .foregroundStyle(Color.black.opacity(0.12))
                    }
                }
            }
            .frame(height: subtitle == nil ? 102 : 112)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

private struct ProgressFillBackground: View {
    let progress: CGFloat
    let fillColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.white

                fillColor
                    .opacity(0.24)
                    .frame(width: proxy.size.width * max(0, min(progress, 1)))
            }
        }
    }
}

#Preview {
    ContentView()
}
