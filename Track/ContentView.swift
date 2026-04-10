import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TodayView()
                .background(Color(.systemGroupedBackground))
        }
    }
}

private struct MealItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let carbs: Int
    let protein: Int
    let fats: Int
}

private struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss

    private let favoriteMeals = [
        MealItem(name: "Favorite 1", calories: 620, carbs: 55, protein: 42, fats: 18),
        MealItem(name: "Favorite 2", calories: 510, carbs: 40, protein: 36, fats: 21)
    ]

    private let recentMeals = [
        MealItem(name: "Last Tracked", calories: 700, carbs: 68, protein: 38, fats: 20),
        MealItem(name: "Last Tracked", calories: 540, carbs: 45, protein: 34, fats: 17)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Add Meal")
                    .font(.system(size: 34, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                searchBar

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(favoriteMeals) { meal in
                        NavigationLink {
                            MealDetailView(meal: meal)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "star")
                                    .font(.title3)
                                    .foregroundStyle(.black)
                                Text(meal.name)
                                    .font(.title3)
                                    .foregroundStyle(.black)
                                Spacer()
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(recentMeals) { meal in
                        NavigationLink {
                            MealDetailView(meal: meal)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text("•")
                                    .font(.title2)
                                    .foregroundStyle(.black)
                                Text(meal.name)
                                    .font(.title3)
                                    .foregroundStyle(.black)
                                Spacer()
                            }
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
                .foregroundStyle(.black)
                .padding(.top, 12)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
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
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today")
                    .font(.system(size: 36, weight: .medium))
                Text("01.01.26")
                    .font(.title3)
            }

            SummaryCard(
                title: "Calories",
                valueText: "1000",
                subtitle: "Remaining",
                macros: [
                    MacroStat(title: "Carbs", value: "0/100"),
                    MacroStat(title: "Protein", value: "0/100"),
                    MacroStat(title: "Fats", value: "0/100")
                ]
            )

            NavigationLink {
                AddMealView()
            } label: {
                HStack(spacing: 0) {
                    Text("+")
                        .font(.title)
                        .frame(width: 56, height: 56)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.black.opacity(0.12))
                                .frame(width: 1)
                        }

                    Text("Add Meal")
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .padding(.horizontal, 18)
                }
                .foregroundStyle(.black)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MealDetailView: View {
    let meal: MealItem

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
                Text("+")
                    .font(.title2)
                    .frame(width: 64, height: 64)

                Text("100")
                    .font(.title2)
                    .frame(width: 140, height: 64)

                Text("g")
                    .font(.title2)
                    .frame(width: 96, height: 64)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.18), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 64)
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 140)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationBarTitleDisplayMode(.inline)
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
                            .font(.title3)
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(macro.value)
                            .font(.system(size: 26, weight: .medium))
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
