import AVFoundation
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
    @State private var searchText = ""
    @State private var searchResults: [MealItem] = []
    @State private var isSearching = false
    @State private var isLoadingMore = false
    @State private var searchError: String?
    @State private var loadMoreError: String?
    @State private var currentSearchQuery = ""
    @State private var nextSearchPage: Int?
    @State private var loadedMealIDs: Set<String> = []
    @State private var lastSearchRequestDate: Date?
    @State private var isShowingBarcodeScanner = false

    private let openFoodFactsClient = OpenFoodFactsClient()
    private let minimumSearchRequestInterval: TimeInterval = 6
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
                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if let searchError {
                        Text(searchError)
                            .font(.body)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else if searchResults.isEmpty {
                        Text(searchText.isEmpty ? "Search for a meal" : "No meals found")
                            .font(.body)
                            .foregroundStyle(Color.black.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(searchResults) { meal in
                            NavigationLink {
                                MealDetailView(meal: meal) { scaledMeal in
                                    selectedMeals.append(scaledMeal)
                                }
                            } label: {
                                MealSearchResultRow(meal: meal)
                            }
                            .onAppear {
                                if meal.id == searchResults.last?.id {
                                    Task {
                                        await loadMoreMealsIfNeeded()
                                    }
                                }
                            }
                        }

                        if isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else if let loadMoreError {
                            Text(loadMoreError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isShowingBarcodeScanner) {
            BarcodeScannerSheet { barcode in
                isShowingBarcodeScanner = false
                Task {
                    await findMeal(forBarcode: barcode)
                }
            }
        }
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
            TextField("Search", text: $searchText)
                .font(.title3)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await searchMeals()
                    }
                }

            Button {
                isShowingBarcodeScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.title3)
                    .foregroundStyle(.black)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.18), lineWidth: 1)
        )
    }

    private func searchMeals() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchError = nil
            loadMoreError = nil
            nextSearchPage = nil
            currentSearchQuery = ""
            loadedMealIDs = []
            return
        }

        guard !isSearching else {
            return
        }

        isSearching = true
        isLoadingMore = false
        searchError = nil
        loadMoreError = nil
        currentSearchQuery = query
        nextSearchPage = nil
        loadedMealIDs = []

        do {
            try await waitForSearchRateLimit()
            let page = try await openFoodFactsClient.searchMeals(matching: query)
            searchResults = uniqueMeals(from: page.meals)
            loadedMealIDs = Set(searchResults.map(\.id))
            nextSearchPage = page.nextPage
        } catch {
            searchResults = []
            searchError = error.localizedDescription
            currentSearchQuery = ""
            nextSearchPage = nil
            loadedMealIDs = []
        }

        isSearching = false
    }

    private func findMeal(forBarcode barcode: String) async {
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBarcode.isEmpty else {
            return
        }

        isSearching = true
        isLoadingMore = false
        searchText = trimmedBarcode
        searchError = nil
        loadMoreError = nil
        currentSearchQuery = ""
        nextSearchPage = nil
        loadedMealIDs = []

        do {
            if let meal = try await openFoodFactsClient.meal(forBarcode: trimmedBarcode) {
                searchResults = [meal]
                loadedMealIDs = [meal.id]
            } else {
                searchResults = []
                searchError = "Kein Produkt mit vollständigen Nährwerten gefunden."
            }
        } catch {
            searchResults = []
            searchError = error.localizedDescription
        }

        isSearching = false
    }

    private func loadMoreMealsIfNeeded() async {
        guard let page = nextSearchPage,
              !currentSearchQuery.isEmpty,
              !isSearching,
              !isLoadingMore else {
            return
        }

        isLoadingMore = true
        loadMoreError = nil

        do {
            var pageToLoad: Int? = page

            while let page = pageToLoad {
                try await waitForSearchRateLimit()
                let searchPage = try await openFoodFactsClient.searchMeals(
                    matching: currentSearchQuery,
                    page: page
                )
                let appendedMealsCount = appendUniqueMeals(searchPage.meals)
                nextSearchPage = searchPage.nextPage

                if appendedMealsCount > 0 || searchPage.nextPage == nil {
                    break
                }

                pageToLoad = searchPage.nextPage
            }
        } catch {
            loadMoreError = error.localizedDescription
        }

        isLoadingMore = false
    }

    private func waitForSearchRateLimit() async throws {
        if let lastSearchRequestDate {
            let elapsedTime = Date().timeIntervalSince(lastSearchRequestDate)
            let remainingDelay = minimumSearchRequestInterval - elapsedTime

            if remainingDelay > 0 {
                try await Task.sleep(nanoseconds: UInt64(remainingDelay * 1_000_000_000))
            }
        }

        lastSearchRequestDate = Date()
    }

    private func uniqueMeals(from meals: [MealItem]) -> [MealItem] {
        var seenIDs: Set<String> = []
        return meals.filter { meal in
            seenIDs.insert(meal.id).inserted
        }
    }

    private func appendUniqueMeals(_ meals: [MealItem]) -> Int {
        var appendedMealsCount = 0

        for meal in meals where loadedMealIDs.insert(meal.id).inserted {
            searchResults.append(meal)
            appendedMealsCount += 1
        }

        return appendedMealsCount
    }
}

private struct MealSearchResultRow: View {
    let meal: MealItem

    var body: some View {
        HStack(spacing: 16) {
            Text(meal.name)
                .font(.title3)
                .foregroundStyle(.black)
                .lineLimit(2)

            Spacer()

            Text("\(meal.calories) kcal")
                .font(.subheadline)
                .foregroundStyle(Color.black.opacity(0.7))
                .monospacedDigit()
                .lineLimit(1)
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

private struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isCameraAuthorized: Bool?

    let onBarcodeScanned: (String) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            scannerContent
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .center)

            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .overlay {
                Text("Scan Barcode")
                    .font(.system(size: 34, weight: .medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Color(.systemGroupedBackground))
        .task {
            isCameraAuthorized = await requestCameraAccess()
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        if isCameraAuthorized == true {
            BarcodeScannerCameraView(onBarcodeScanned: onBarcodeScanned)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.18), lineWidth: 1)
                }
        } else if isCameraAuthorized == false {
            Text("Camera access is required to scan barcodes.")
                .font(.body)
                .foregroundStyle(Color.black.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
        } else {
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    private func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .authorized {
            return true
        }

        if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .video)
        }

        return false
    }
}

private struct BarcodeScannerCameraView: UIViewControllerRepresentable {
    let onBarcodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        BarcodeScannerViewController(onBarcodeScanned: onBarcodeScanned)
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.onBarcodeScanned = onBarcodeScanned
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeScannerViewController, coordinator: ()) {
        uiViewController.stopScanning()
    }
}

private final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeScanned: (String) -> Void

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "Track.BarcodeScanner.SessionQueue")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScanBarcode = false

    init(onBarcodeScanned: @escaping (String) -> Void) {
        self.onBarcodeScanned = onBarcodeScanned
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCaptureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    func startScanning() {
        sessionQueue.async { [captureSession] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    func stopScanning() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        defer {
            captureSession.commitConfiguration()
        }

        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: captureDevice),
              captureSession.canAddInput(videoInput) else {
            showScannerError("Camera is not available.")
            return
        }

        captureSession.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            showScannerError("Barcode scanning is not available.")
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

        let supportedTypes: [AVMetadataObject.ObjectType] = [
            .ean8,
            .ean13,
            .upce,
            .code39,
            .code39Mod43,
            .code93,
            .code128,
            .itf14,
            .interleaved2of5,
            .qr,
            .dataMatrix,
            .pdf417,
            .aztec
        ]
        let availableTypes = metadataOutput.availableMetadataObjectTypes
        metadataOutput.metadataObjectTypes = supportedTypes.filter { availableTypes.contains($0) }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func showScannerError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScanBarcode,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = metadataObject.stringValue else {
            return
        }

        didScanBarcode = true
        stopScanning()
        onBarcodeScanned(barcode)
    }
}

private struct TodayView: View {
    let loggedMeals: [LoggedMealEntry]
    let onAddMeals: ([MealItem]) -> Void
    let onDeleteMeal: (LoggedMealEntry) -> Void

    @AppStorage("caloriesGoal") private var caloriesGoal = 2700
    @AppStorage("carbsGoal") private var carbsGoal = 250
    @AppStorage("proteinGoal") private var proteinGoal = 150
    @AppStorage("fatsGoal") private var fatsGoal = 80

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

                ZStack(alignment: .topTrailing) {
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

                    NavigationLink {
                        AdjustMacrosView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
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

private struct AdjustMacrosView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("caloriesGoal") private var caloriesGoal = 2700
    @AppStorage("carbsGoal") private var carbsGoal = 250
    @AppStorage("proteinGoal") private var proteinGoal = 150
    @AppStorage("fatsGoal") private var fatsGoal = 80

    @State private var draftCaloriesGoal = 2700
    @State private var draftCarbsGoal = 250
    @State private var draftProteinGoal = 150
    @State private var draftFatsGoal = 80
    @State private var editingMacro: AdjustableMacro?
    @State private var editedValueText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Adjust")
                .font(.system(size: 34, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            SummaryCard(
                title: "Calories",
                valueText: "\(draftCaloriesGoal)",
                subtitle: nil,
                topSectionProgress: 1,
                topSectionFillColor: .green,
                topSectionAction: {
                    startEditing(.calories)
                },
                macros: [
                    MacroStat(
                        title: "Carbs",
                        value: "\(draftCarbsGoal)",
                        progress: 1,
                        fillColor: .brown,
                        action: {
                            startEditing(.carbs)
                        }
                    ),
                    MacroStat(
                        title: "Protein",
                        value: "\(draftProteinGoal)",
                        progress: 1,
                        fillColor: .orange,
                        action: {
                            startEditing(.protein)
                        }
                    ),
                    MacroStat(
                        title: "Fats",
                        value: "\(draftFatsGoal)",
                        progress: 1,
                        fillColor: .yellow,
                        action: {
                            startEditing(.fats)
                        }
                    )
                ]
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadDraftValues()
        }
        .alert(editingMacro?.title ?? "", isPresented: isShowingEditAlert) {
            TextField("Target", text: $editedValueText)
                .keyboardType(.numberPad)

            Button("Cancel", role: .cancel) {
                editingMacro = nil
            }

            Button("Save") {
                applyEditedValue()
            }
        }
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
                    saveDraftValues()
                    dismiss()
                } label: {
                    Text("Save")
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

    private var isShowingEditAlert: Binding<Bool> {
        Binding(
            get: { editingMacro != nil },
            set: { isPresented in
                if !isPresented {
                    editingMacro = nil
                }
            }
        )
    }

    private func startEditing(_ macro: AdjustableMacro) {
        editingMacro = macro
        editedValueText = "\(value(for: macro))"
    }

    private func value(for macro: AdjustableMacro) -> Int {
        switch macro {
        case .calories:
            draftCaloriesGoal
        case .carbs:
            draftCarbsGoal
        case .protein:
            draftProteinGoal
        case .fats:
            draftFatsGoal
        }
    }

    private func applyEditedValue() {
        guard let editingMacro,
              let value = Int(editedValueText.filter(\.isNumber)),
              value > 0 else {
            self.editingMacro = nil
            return
        }

        switch editingMacro {
        case .calories:
            draftCaloriesGoal = value
        case .carbs:
            draftCarbsGoal = value
        case .protein:
            draftProteinGoal = value
        case .fats:
            draftFatsGoal = value
        }

        self.editingMacro = nil
    }

    private func loadDraftValues() {
        draftCaloriesGoal = caloriesGoal
        draftCarbsGoal = carbsGoal
        draftProteinGoal = proteinGoal
        draftFatsGoal = fatsGoal
    }

    private func saveDraftValues() {
        caloriesGoal = draftCaloriesGoal
        carbsGoal = draftCarbsGoal
        proteinGoal = draftProteinGoal
        fatsGoal = draftFatsGoal
    }
}

private enum AdjustableMacro: Identifiable {
    case calories
    case carbs
    case protein
    case fats

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .calories:
            "Calories"
        case .carbs:
            "Carbs"
        case .protein:
            "Protein"
        case .fats:
            "Fats"
        }
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

                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: 72, height: 56)
                        .contentShape(Rectangle())
                        .gesture(swipeToDeleteGesture(rowWidth: proxy.size.width))
                }
            }
        }
        .frame(height: 56)
    }

    private func swipeToDeleteGesture(rowWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                horizontalOffset = min(0, value.translation.width)
            }
            .onEnded { value in
                let deleteThreshold = rowWidth * 0.5
                let shouldDelete = abs(value.translation.width) > deleteThreshold

                if shouldDelete {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        horizontalOffset = -rowWidth
                    }
                    onDelete()
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        horizontalOffset = 0
                    }
                }
            }
    }
}

private struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var gramsText = "100"
    @State private var selectedMeasure: MealDetailMeasure = .grams

    let meal: MealItem
    let onAdd: (MealItem) -> Void

    private var amountValue: Int {
        max(Int(gramsText) ?? 0, 0)
    }

    private var gramsValue: Double {
        switch selectedMeasure {
        case .grams:
            Double(amountValue)
        case .productMeasure(let option):
            Double(amountValue) * option.grams
        }
    }

    private var scaleFactor: Double {
        gramsValue / 100
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

    private var availableMeasures: [MealDetailMeasure] {
        [.grams] + meal.measureOptions.map(MealDetailMeasure.productMeasure)
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
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(.black)
                    .onChange(of: gramsText) { _, newValue in
                        let filteredValue = newValue.filter(\.isNumber)
                        if filteredValue != newValue {
                            gramsText = filteredValue
                        }
                    }

                Menu {
                    ForEach(availableMeasures) { measure in
                        Button(measure.displayTitle) {
                            selectMeasure(measure)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedMeasure.displayTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if !meal.measureOptions.isEmpty {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                    }
                    .font(.title2)
                    .frame(width: 180, height: 64)
                    .foregroundStyle(.black)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(meal.measureOptions.isEmpty)
            }
            .frame(maxWidth: .infinity)
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
                        .frame(maxWidth: .infinity)
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(width: 1)
                    Spacer()
                        .frame(width: 180)
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

    private func selectMeasure(_ measure: MealDetailMeasure) {
        guard measure != selectedMeasure else {
            return
        }

        switch (selectedMeasure, measure) {
        case (.grams, .productMeasure):
            gramsText = "1"
        case (.productMeasure, .grams):
            gramsText = "\(Int(gramsValue.rounded()))"
        case (.productMeasure, .productMeasure):
            gramsText = "1"
        case (.grams, .grams):
            break
        }

        selectedMeasure = measure
    }
}

private enum MealDetailMeasure: Identifiable, Hashable {
    case grams
    case productMeasure(MealMeasureOption)

    var id: String {
        switch self {
        case .grams:
            "grams"
        case .productMeasure(let option):
            option.id
        }
    }

    var displayTitle: String {
        switch self {
        case .grams:
            "g"
        case .productMeasure(let option):
            option.displayTitle
        }
    }
}

private struct MacroStat: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let progress: CGFloat
    let fillColor: Color
    let action: (() -> Void)?

    init(
        title: String,
        value: String,
        progress: CGFloat,
        fillColor: Color,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.progress = progress
        self.fillColor = fillColor
        self.action = action
    }
}

private struct SummaryCard: View {
    let title: String
    let valueText: String
    let subtitle: String?
    let valueColor: Color
    let subtitleColor: Color
    let topSectionProgress: CGFloat
    let topSectionFillColor: Color
    let topSectionAction: (() -> Void)?
    let macros: [MacroStat]

    init(
        title: String,
        valueText: String,
        subtitle: String?,
        valueColor: Color = .black,
        subtitleColor: Color = .black,
        topSectionProgress: CGFloat = 0,
        topSectionFillColor: Color = .green,
        topSectionAction: (() -> Void)? = nil,
        macros: [MacroStat]
    ) {
        self.title = title
        self.valueText = valueText
        self.subtitle = subtitle
        self.valueColor = valueColor
        self.subtitleColor = subtitleColor
        self.topSectionProgress = topSectionProgress
        self.topSectionFillColor = topSectionFillColor
        self.topSectionAction = topSectionAction
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
            .contentShape(Rectangle())
            .onTapGesture {
                topSectionAction?()
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        macro.action?()
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
