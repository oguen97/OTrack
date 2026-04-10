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

                TodayView(loggedMeals: loggedMeals) { newMeals in
                    let timestamp = Date()
                    loggedMeals.append(
                        contentsOf: newMeals.map {
                            LoggedMealEntry(meal: $0, addedAt: timestamp)
                        }
                    )
                }
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
                            MealDetailView(meal: meal) {
                                selectedMeals.append(
                                    MealItem(
                                        name: meal.name,
                                        calories: meal.calories,
                                        carbs: meal.carbs,
                                        protein: meal.protein,
                                        fats: meal.fats
                                    )
                                )
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
                    valueText: "\(remainingCalories)",
                    subtitle: "Remaining",
                    macros: [
                        MacroStat(title: "Carbs", value: "\(totalCarbs)/\(carbsGoal)"),
                        MacroStat(title: "Protein", value: "\(totalProtein)/\(proteinGoal)"),
                        MacroStat(title: "Fats", value: "\(totalFats)/\(fatsGoal)")
                    ]
                )
                .padding(.bottom, loggedMeals.isEmpty ? 0 : 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if !loggedMeals.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("My Meals")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.black)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(loggedMeals) { entry in
                                HStack(spacing: 0) {
                                    Text(entry.meal.name)
                                        .font(.title3)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Rectangle()
                                        .fill(Color.black.opacity(0.05))
                                        .frame(width: 1, height: 32)

                                    Text(timeString(for: entry.addedAt))
                                        .font(.subheadline)
                                        .foregroundStyle(Color.black.opacity(0.7))
                                        .frame(width: 72)
                                }
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

private struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let meal: MealItem
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text(meal.name)
                .font(.system(size: 34, weight: .medium))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            SummaryCard(
                title: "Calories",
                valueText: "\(meal.calories)",
                subtitle: nil,
                macros: [
                    MacroStat(title: "Carbs", value: "\(meal.carbs)"),
                    MacroStat(title: "Protein", value: "\(meal.protein)"),
                    MacroStat(title: "Fats", value: "\(meal.fats)")
                ]
            )

            HStack(spacing: 0) {
                Button {
                    onAdd()
                    dismiss()
                } label: {
                    Text("+")
                        .font(.title2)
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.black)
                }

                Text("100")
                    .font(.title2)
                    .frame(width: 140, height: 64)
                    .foregroundStyle(.black)

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
}

private struct MacroStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct SummaryCard: View {
    let title: String
    let valueText: String
    let subtitle: String?
    let macros: [MacroStat]

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
                    .font(.title2)
                VStack(spacing: 8) {
                    Text(valueText)
                        .font(.system(size: 48, weight: .medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: topSectionHeight)
            .background(Color.white)

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.black.opacity(0.12))

            HStack(spacing: 0) {
                ForEach(Array(macros.enumerated()), id: \.element.id) { index, macro in
                    VStack(spacing: 0) {
                        Text(macro.title)
                            .font(.title3)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(macro.value)
                            .font(.system(size: 22, weight: .medium))
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

#Preview {
    ContentView()
}
