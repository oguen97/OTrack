import Foundation

struct MealItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let carbs: Int
    let protein: Int
    let fats: Int
}

enum SampleMeals {
    static let items: [MealItem] = [
        MealItem(name: "Chicken Rice Bowl", calories: 620, carbs: 55, protein: 42, fats: 18),
        MealItem(name: "Oats with Berries", calories: 510, carbs: 40, protein: 36, fats: 21),
        MealItem(name: "Salmon Potato Plate", calories: 700, carbs: 68, protein: 38, fats: 20),
        MealItem(name: "Greek Yogurt Mix", calories: 540, carbs: 45, protein: 34, fats: 17),
        MealItem(name: "Turkey Sandwich", calories: 430, carbs: 39, protein: 31, fats: 12),
        MealItem(name: "Beef Burrito Bowl", calories: 780, carbs: 72, protein: 46, fats: 24),
        MealItem(name: "Pasta Bolognese", calories: 690, carbs: 74, protein: 33, fats: 19),
        MealItem(name: "Protein Pancakes", calories: 560, carbs: 48, protein: 37, fats: 16),
        MealItem(name: "Tuna Wrap", calories: 470, carbs: 35, protein: 34, fats: 14),
        MealItem(name: "Egg Avocado Toast", calories: 520, carbs: 32, protein: 24, fats: 28),
        MealItem(name: "Shrimp Fried Rice", calories: 640, carbs: 69, protein: 35, fats: 18),
        MealItem(name: "Cottage Cheese Bowl", calories: 390, carbs: 21, protein: 33, fats: 15),
        MealItem(name: "Steak with Sweet Potato", calories: 750, carbs: 58, protein: 49, fats: 26),
        MealItem(name: "Quinoa Chickpea Salad", calories: 480, carbs: 53, protein: 18, fats: 20),
        MealItem(name: "Chicken Caesar Wrap", calories: 610, carbs: 41, protein: 39, fats: 25),
        MealItem(name: "Banana Protein Shake", calories: 360, carbs: 30, protein: 29, fats: 11),
        MealItem(name: "Yogurt Granola Cup", calories: 410, carbs: 44, protein: 20, fats: 14),
        MealItem(name: "Tofu Stir Fry", calories: 530, carbs: 47, protein: 26, fats: 21),
        MealItem(name: "Rice Cake Snack Plate", calories: 280, carbs: 33, protein: 12, fats: 9),
        MealItem(name: "Chicken Alfredo", calories: 820, carbs: 67, protein: 45, fats: 31),
        MealItem(name: "Lentil Soup", calories: 340, carbs: 42, protein: 19, fats: 8),
        MealItem(name: "Sushi Bowl", calories: 590, carbs: 63, protein: 32, fats: 16),
        MealItem(name: "Peanut Butter Oats", calories: 600, carbs: 54, protein: 24, fats: 29),
        MealItem(name: "Egg White Omelette", calories: 310, carbs: 8, protein: 34, fats: 14),
        MealItem(name: "Halloumi Veggie Plate", calories: 550, carbs: 29, protein: 23, fats: 34),
        MealItem(name: "Chili con Carne", calories: 670, carbs: 52, protein: 41, fats: 24),
        MealItem(name: "Protein Bar Snack", calories: 250, carbs: 22, protein: 20, fats: 9),
        MealItem(name: "Poke Bowl", calories: 610, carbs: 57, protein: 36, fats: 19),
        MealItem(name: "Baked Potato Tuna", calories: 495, carbs: 46, protein: 30, fats: 15),
        MealItem(name: "French Toast Stack", calories: 575, carbs: 61, protein: 28, fats: 20)
    ]
}
