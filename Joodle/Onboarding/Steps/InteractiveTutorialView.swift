//
//  InteractiveTutorialView.swift
//  Joodle
//
//  Interactive tutorial view that teaches users app features in a sandboxed environment.
//

import SwiftUI

struct InteractiveTutorialView: View {
    /// ViewModel for onboarding flow (nil when used standalone from Settings)
    private var viewModel: OnboardingViewModel?

    // Tutorial state
    @StateObject private var coordinator: TutorialCoordinator
    @StateObject private var mockStore: MockDataStore

    // Animation state
    @State private var hasAnimatedIn = false
    @State private var gridOpacity: Double = 0
    @State private var overlayOpacity: Double = 0

    // Transition safety: blocks all grid interactions until overlay is ready
    @State private var isTransitionComplete = false

    // View state
    @State private var showDrawingCanvas = false
    @State private var showReminderSheet = false
    @State private var isScrubbing = false
    @State private var highlightedId: String?

    // Scroll state for auto-scrolling to doodle
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasScrolledToEntry = false

    // Standalone mode state (for black screen fix when presented as fullScreenCover)
    @State private var isReady = false
    @State private var forceRefresh = UUID()

    // Configuration
    let singleStepMode: Bool
    let startingStepType: TutorialStepType?
    let onDismiss: (() -> Void)?

    /// Whether this is shown during onboarding (vs from Settings)
    var isOnboarding: Bool {
        viewModel != nil && !singleStepMode
    }

    /// Whether the current step is a gesture hint step (fully interactable screen)
    private var isGestureHintStep: Bool {
        guard let step = coordinator.currentStep else { return false }
        if case .gesture = step.highlightAnchor {
            return true
        }
        return false
    }

    /// Whether the current step is the scrubbing step (disable scroll to prevent accidental scrolling)
    private var isScrubbingStep: Bool {
        coordinator.currentStep?.type == .scrubbing
    }

    /// Whether device has Dynamic Island
    private var hasDynamicIsland: Bool {
        UIDevice.hasDynamicIsland
    }

    // MARK: - Init (Onboarding mode)

    init(
        viewModel: OnboardingViewModel,
        singleStepMode: Bool = false,
        startingStepType: TutorialStepType? = nil
    ) {
        self.viewModel = viewModel
        self.singleStepMode = singleStepMode
        self.startingStepType = startingStepType
        self.onDismiss = nil

        let steps = singleStepMode && startingStepType != nil
            ? TutorialSteps.singleStep(startingStepType!)
            : TutorialSteps.onboarding

        let startIndex = startingStepType != nil && !singleStepMode
            ? TutorialSteps.startingIndex(for: startingStepType!)
            : 0

        _coordinator = StateObject(wrappedValue: TutorialCoordinator(
            steps: steps,
            startingIndex: startIndex,
            singleStepMode: singleStepMode,
            onComplete: { }
        ))

        _mockStore = StateObject(wrappedValue: MockDataStore())
    }

    // MARK: - Init (Standalone mode from Settings)

    init(
        stepType: TutorialStepType,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = nil
        self.singleStepMode = true
        self.startingStepType = stepType
        self.onDismiss = onDismiss

        let steps = TutorialSteps.singleStep(stepType)

        _coordinator = StateObject(wrappedValue: TutorialCoordinator(
            steps: steps,
            startingIndex: 0,
            singleStepMode: true,
            onComplete: { }
        ))

        _mockStore = StateObject(wrappedValue: MockDataStore())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background always visible (prevents black screen in standalone mode)
            Color.backgroundColor
                .ignoresSafeArea()

            // Main content - conditionally rendered for standalone mode
            if isOnboarding || isReady {
                GeometryReader { geometry in
                    ZStack {
                        // Main tutorial content
                        tutorialContent(geometry: geometry)
                            .opacity(gridOpacity)

                        // Dynamic Island expanded view for drawing canvas (on supported devices)
                        if hasDynamicIsland {
                            DynamicIslandExpandedView(
                                isExpanded: $showDrawingCanvas,
                                content: {
                                    DrawingCanvasView(
                                        date: mockStore.selectedDateItem?.date ?? Date(),
                                        entry: nil,
                                        onDismiss: {
                                            showDrawingCanvas = false
                                        },
                                        isShowing: showDrawingCanvas,
                                        mockStore: mockStore,
                                        mockEntry: mockStore.selectedEntry
                                    )
                                    .tutorialHighlightAnchor(.drawingCanvas)
                                },
                                hidden: false,
                                onDismiss: {
                                    showDrawingCanvas = false
                                }
                            )
                        }

                        // Gesture-blocking overlay during transition (before tutorial overlay is ready)
                        // This prevents accidental taps on the grid during the scroll animation
                        if !isTransitionComplete {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                                .allowsHitTesting(true)
                                .onTapGesture { } // Absorb all taps
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in } // Absorb all drags
                                )
                                .ignoresSafeArea()
                        }

                        // Tutorial overlay (dimmed with cutout + tooltip)
                        if coordinator.isActive && hasAnimatedIn {
                            TutorialOverlayView(coordinator: coordinator)
                                .opacity(overlayOpacity)
                        }

                        // Exit/Skip tutorial button (hide when showing completion)
                        if !coordinator.showingCompletion {
                            exitTutorialButton
                                .opacity(overlayOpacity)
                        }

                        #if DEBUG
                        // Debug overlay for development - now draggable
                        TutorialDebugOverlay(coordinator: coordinator)
                        #endif
                    }
                    .onPreferenceChange(HighlightFramePreferenceKey.self) { frames in
                        #if DEBUG
                        // Debug: Log bellIcon frame registration
                        if let bellFrame = frames[TutorialButtonId.bellIcon.rawValue] {
                            print("🔔 [addReminder] bellIcon frame: \(Int(bellFrame.minX)),\(Int(bellFrame.minY)) ✓")
                        }
                        #endif

                        frames.forEach { key, frame in
                            coordinator.registerHighlightFrame(id: key, frame: frame)
                        }
                    }
                }
                .id(forceRefresh)  // Force view recreation on refresh (standalone mode)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            setupInitialState()
            animateIn()
        }
        .task {
            // For standalone mode: delay to ensure fullScreenCover transition completes
            if !isOnboarding {
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
                await MainActor.run {
                    forceRefresh = UUID()
                    withAnimation(.easeIn(duration: 0.2)) {
                        isReady = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tutorialPrerequisiteNeeded)) { notification in
            handlePrerequisite(notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tutorialDoubleTapCompleted)) { _ in
            handleDoubleTapCompleted()
        }
        .onChange(of: mockStore.viewMode) { oldValue, newValue in
            handleViewModeChange(from: oldValue, to: newValue)
        }
        .onChange(of: mockStore.selectedYear) { oldValue, newValue in
            handleYearChange(from: oldValue, to: newValue)
        }
        .onChange(of: showDrawingCanvas) { oldValue, newValue in
            handleDrawingCanvasChange(from: oldValue, to: newValue)
        }
        .onChange(of: showReminderSheet) { oldValue, newValue in
            handleReminderSheetChange(from: oldValue, to: newValue)
        }
        .onChange(of: isScrubbing) { oldValue, newValue in
            handleScrubbingChange(from: oldValue, to: newValue)
        }
        // Safety: If bottom view appears during scrubbing step transition, dismiss it and re-scroll
        .onChange(of: mockStore.selectedDateItem) { oldValue, newValue in
            handleSelectionChangeDuringTransition(from: oldValue, to: newValue)
        }
        // Watch for tutorial completion to navigate to next step or dismiss
        .onChange(of: coordinator.isActive) { oldValue, newValue in
            // Tutorial just became inactive (completed)
            if oldValue == true && newValue == false {
                if isOnboarding {
                    viewModel?.completeStep(.yearGridDemo)
                } else {
                    onDismiss?()
                }
            }
        }
    }

    // MARK: - Exit Tutorial Button

    private var exitTutorialButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
              if #available(iOS 26.0, *) {
                Button {
                  exitTutorial()
                } label: {
                  HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                      .font(.body)
                    Text(isOnboarding ? "Skip tutorial" : "Exit tutorial")
                      .font(.subheadline.weight(.medium))
                  }
                  .foregroundColor(.primary)
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .clipShape(Capsule())
                }
                .glassEffect(.regular.interactive())
              } else {
                // Fallback on earlier versions
                Button {
                  exitTutorial()
                } label: {
                  HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                      .font(.body)
                    Text(isOnboarding ? "Skip tutorial" : "Exit tutorial")
                      .font(.subheadline.weight(.medium))
                  }
                  .foregroundColor(.white.opacity(0.9))
                  .padding(.horizontal, 16)
                  .padding(.vertical, 10)
                  .background(Color.black.opacity(0.6))
                  .clipShape(Capsule())
                }
              }
                Spacer()
            }
            .padding(.bottom, 40)
        }
    }

    private func exitTutorial() {
        // skipAll() handles navigation via its onComplete callback
        // For onboarding: onComplete calls viewModel.completeStep(.yearGridDemo)
        // For standalone: onComplete calls onDismiss
        // Do NOT call completeStep here to avoid double navigation which can corrupt the navigation path
        coordinator.skipAll()
    }

    // MARK: - Tutorial Content

    @ViewBuilder
    private func tutorialContent(geometry: GeometryProxy) -> some View {
        let itemsSpacing = calculateSpacing(
            containerWidth: geometry.size.width,
            viewMode: mockStore.viewMode
        )

        ZStack(alignment: .top) {
            // Resizable split view with grid and entry editing
            ResizableSplitView(
                top: {
                    // Year grid with ScrollViewReader for auto-scrolling
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 100)

                                YearGridView(
                                    year: mockStore.selectedYear,
                                    viewMode: mockStore.viewMode,
                                    dotsSpacing: itemsSpacing,
                                    items: mockStore.itemsInYear,
                                    entries: mockEntriesToDayEntries(),
                                    highlightedItemId: isScrubbing ? highlightedId : nil,
                                    selectedItemId: mockStore.selectedDateItem?.id
                                )
                                // Scrubbing gesture - overlay on YearGridView so location is relative to grid
                                .overlay(
                                    LongPressScrubRecognizer(
                                        isScrubbing: $isScrubbing,
                                        minimumPressDuration: 0.2,
                                        allowableMovement: 20,
                                        onBegan: { location in
                                            highlightedId = nil
                                            isScrubbing = true
                                            coordinator.isUserScrubbing = true  // Hide highlight overlay
                                            mockStore.clearSelection()
                                            let newId = getItemId(at: location, geometry: geometry)
                                            if highlightedId == nil { Haptic.play(with: .medium) }
                                            highlightedId = newId
                                        },
                                        onChanged: { location in
                                            let newId = getItemId(at: location, geometry: geometry)
                                            if newId != highlightedId { Haptic.play() }
                                            highlightedId = newId
                                        },
                                        onEnded: { location in
                                            if let highlightedId, let item = getItem(from: highlightedId) {
                                                mockStore.selectDate(item.date)
                                            }
                                            highlightedId = nil
                                            isScrubbing = false
                                            coordinator.isUserScrubbing = false  // Show highlight overlay again (if still on scrubbing step)
                                        }
                                    )
                                    .allowsHitTesting(true)
                                )
                                // Tap gesture - allow taps to pass through when not scrubbing
                                .onTapGesture { location in
                                    handleGridTap(at: location, geometry: geometry)
                                }
                                // Pinch gesture
                                .simultaneousGesture(
                                    MagnificationGesture()
                                        .onEnded { value in
                                            handlePinchGesture(value: value)
                                        }
                                )
                                // Register highlight anchor for today's entry
                                .overlay(
                                    todayEntryAnchorOverlay(geometry: geometry, itemsSpacing: itemsSpacing)
                                )

                                // Scroll anchor for today's entry - must be direct child of ScrollView content
                                Color.clear
                                    .frame(height: 1)
                                    .id("todayEntryAnchor")
                                    .offset(y: -calculateTodayEntryOffset(itemsSpacing: itemsSpacing))

                                // Extra space at bottom for scrolling
                                Spacer().frame(height: 200)
                            }
                        }
                        .background(Color.backgroundColor)
                        // Disable scroll during scrubbing step (prevents accidental scroll when tap doesn't hold long enough)
                        // Also disable when actively scrubbing
                        .scrollDisabled(isScrubbingStep || isScrubbing)
                        .onAppear {
                            scrollProxy = proxy
                        }
                    }
                },
                bottom: {
                    // Entry editing view - using real view with mock store
                    EntryEditingView(
                        date: mockStore.selectedDateItem?.date,
                        onOpenDrawingCanvas: {
                            handlePaintButtonTapped()
                        },
                        onFocusChange: nil,
                        mockStore: mockStore,
                        tutorialMode: true,
                        showReminderSheetBinding: $showReminderSheet
                    )
                },
                hasBottomView: mockStore.selectedDateItem != nil,
                onBottomDismissed: {
                    mockStore.clearSelection()
                },
                onTopViewHeightChange: { _ in
                    // When bottom view appears/resizes, scroll to keep selected entry visible
                    scrollToSelectedEntry()
                },
                tutorialMode: true,
                allowHandleDrag: isGestureHintStep  // Allow dragging during gesture hint steps
            )
            .ignoresSafeArea(.container, edges: .bottom)

            // Header - using custom tutorial header that only shows year
            TutorialHeaderView(
                mockStore: mockStore,
                geometry: geometry,
                highlightedItemId: highlightedId,
                entries: mockEntriesToDayEntries()
            )
        }
        // Drawing canvas sheet - for devices WITHOUT Dynamic Island
        .sheet(isPresented: hasDynamicIsland ? .constant(false) : $showDrawingCanvas) {
            ZStack {
                DrawingCanvasView(
                    date: mockStore.selectedDateItem?.date ?? Date(),
                    entry: nil,
                    onDismiss: {
                        showDrawingCanvas = false
                    },
                    isShowing: showDrawingCanvas,
                    mockStore: mockStore,
                    mockEntry: mockStore.selectedEntry
                )

                // Tutorial overlay inside the sheet for non-Dynamic Island devices
                // Only show when on the drawing canvas sub-step of drawAndEdit
                if coordinator.isActive,
                   let step = coordinator.currentStep,
                   step.type == .drawAndEdit,
                   step.highlightAnchor == .drawingCanvas {
                    SheetTutorialOverlay(
                        tooltip: step.tooltip
                    )
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Reminder sheet - using real view with mock store
        .sheet(isPresented: $showReminderSheet) {
            if let date = mockStore.selectedDateItem?.date {
                ReminderSheet(
                    dateString: CalendarDate.from(date).dateString,
                    entryBody: mockStore.selectedEntry?.body,
                    mockStore: mockStore
                )
                .presentationDetents([.height(280)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func todayEntryAnchorOverlay(geometry: GeometryProxy, itemsSpacing: CGFloat) -> some View {
        let todayIndex = getTodayIndex()
        let dotSize = mockStore.viewMode.dotSize
        let dotsPerRow = mockStore.viewMode.dotsPerRow
        let row = todayIndex / dotsPerRow
        let col = todayIndex % dotsPerRow
      let x = GRID_HORIZONTAL_PADDING + CGFloat(col) * (dotSize + itemsSpacing) - dotSize * 1.5
      let y = CGFloat(row) * (dotSize + itemsSpacing) - dotSize * 1.5

        // Position a small anchor view exactly at today's entry location
        // and use GeometryReader on that specific view to get accurate frame
        Color.clear
            .frame(width: dotSize * 4, height: dotSize * 4)
            .background(
                GeometryReader { entryGeo in
                    Color.clear
                        .preference(
                            key: HighlightFramePreferenceKey.self,
                            value: ["gridEntry.0": entryGeo.frame(in: .global)]
                        )
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: x, y: y)
    }

    /// Calculate the Y offset from the bottom of the grid to today's entry
    private func calculateTodayEntryOffset(itemsSpacing: CGFloat) -> CGFloat {
        let todayIndex = getTodayIndex()
        let dotSize = mockStore.viewMode.dotSize
        let dotsPerRow = mockStore.viewMode.dotsPerRow
        let row = todayIndex / dotsPerRow
        let totalRows = (mockStore.itemsInYear.count + dotsPerRow - 1) / dotsPerRow

        // Calculate distance from today's row to bottom
        let rowsFromBottom = totalRows - row - 1
        return CGFloat(rowsFromBottom) * (dotSize + itemsSpacing) + dotSize / 2
    }

    // MARK: - Setup & Animation

    private func setupInitialState() {
        if isOnboarding {
            // Onboarding mode: use user's doodle from onboarding flow
            if let drawingData = viewModel?.firstJoodleData {
                mockStore.populateUserDrawing(drawingData)
            } else {
                mockStore.populateUserDrawing(PLACEHOLDER_DATA)
            }
        } else {
            // Standalone mode: setup based on step type
            mockStore.populateUserDrawing(PLACEHOLDER_DATA)

            switch startingStepType {
            case .scrubbing:
                break // Just need the grid with today's entry visible

            case .quickSwitchToday:
                // Need bottom view visible so center handle is shown
                mockStore.selectDate(Date())

            case .drawAndEdit:
                // First sub-step needs EntryEditingView open to show paint button
                mockStore.selectDate(Date())

            case .switchViewMode:
                // First sub-step needs viewModeButton visible (always in header)
                break

            case .switchYear:
                // Year selector is always visible in header
                break

            case .addReminder:
                // Need future year with anniversary entry, and EntryEditingView open
                mockStore.ensureFutureYear()
                mockStore.populateAnniversaryEntry()

            case .none:
                break
            }
        }
    }

    private func animateIn() {
        // Animate grid fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            gridOpacity = 1.0
        }

        // Only scroll to today for steps that need it
        // addReminder shows future year content, switchYear doesn't need scroll
        let needsScrollToToday = startingStepType != .addReminder && startingStepType != .switchYear

        // Scroll to today's entry after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if needsScrollToToday || isOnboarding {
                scrollToTodayEntry()
            }
        }

        // Show tutorial overlay after grid appears and scrolls
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hasAnimatedIn = true
            withAnimation(.easeIn(duration: 0.3)) {
                overlayOpacity = 1.0
            }
            // Mark transition as complete - now user can interact with the grid
            isTransitionComplete = true
        }
    }

    private func scrollToTodayEntry() {
        guard !hasScrolledToEntry else { return }
        hasScrolledToEntry = true

        withAnimation(.easeInOut(duration: 0.6)) {
            scrollProxy?.scrollTo("todayEntryAnchor", anchor: .center)
        }
    }

    /// Scroll to the currently selected entry (used when bottom view appears)
    private func scrollToSelectedEntry() {
        guard let selectedItem = mockStore.selectedDateItem else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            scrollProxy?.scrollTo(selectedItem.id, anchor: .center)
        }
    }

    // MARK: - Prerequisite Handling

    private func handlePrerequisite(_ notification: Notification) {
        guard let prerequisite = notification.userInfo?["prerequisite"] as? TutorialPrerequisite else { return }

        switch prerequisite {
        case .ensureFutureYear:
            mockStore.ensureFutureYear()

        case .populateAnniversaryEntry:
            // First clear any existing selection to avoid capturing frames during transition
            mockStore.clearSelection()

            // Wait for clear animation to finish, then populate and select anniversary entry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                mockStore.ensureFutureYear()
                mockStore.populateAnniversaryEntry()
            }

        case .openEntryEditingView:
            // Entry should already be open from scrubbing step
            if mockStore.selectedDateItem == nil {
                mockStore.selectDate(Date())
            }

        case .clearSelectionAndScroll:
            // Deselect any selected entry to dismiss the bottom entry editing view
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                mockStore.clearSelection()
            }
            // Reset scroll flag and scroll to today's entry again
            hasScrolledToEntry = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scrollToTodayEntry()
            }

        case .navigateToToday:
            // Simulate the effect of double-tapping the center handle
            // Scroll to today's entry and select it
            hasScrolledToEntry = false
            scrollToTodayEntry()
            // Small delay to let scroll complete, then select today
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                mockStore.selectDate(Date())
            }
        }
    }

    // MARK: - Event Handlers

    private func handlePaintButtonTapped() {
        Haptic.play()

        // Check if current step expects paint button tap
        if let step = coordinator.currentStep,
           case .buttonTapped(let buttonId) = step.endCondition,
           buttonId == .paintButton {
            // Advance to next step first, then open canvas
            coordinator.advance()
        }

        // Open the drawing canvas
        showDrawingCanvas = true
    }

    private func handleViewModeChange(from oldValue: ViewMode, to newValue: ViewMode) {
        guard let step = coordinator.currentStep else { return }

        if case .viewModeChanged(let targetMode) = step.endCondition {
            if newValue == targetMode {
                coordinator.advance()
            }
        }

        // Check for pinch gesture completion (expanding from year to now)
        if case .pinchGestureCompleted = step.endCondition {
            if oldValue == .year && newValue == .now {
                coordinator.advance()
            }
        }
    }

    private func handleYearChange(from oldValue: Int, to newValue: Int) {
        guard let step = coordinator.currentStep else { return }

        if case .yearChanged = step.endCondition {
            if newValue != oldValue {
                coordinator.advance()
            }
        }
    }

    private func handleDrawingCanvasChange(from oldValue: Bool, to newValue: Bool) {
        guard let step = coordinator.currentStep else { return }

        // Canvas was dismissed
        if oldValue == true && newValue == false {
            if case .viewDismissed(let viewId) = step.endCondition {
                if viewId == "drawingCanvas" {
                    coordinator.advance()
                }
            }
        }
    }

    private func handleReminderSheetChange(from oldValue: Bool, to newValue: Bool) {
        guard let step = coordinator.currentStep else { return }

        // Sheet was dismissed
        if oldValue == true && newValue == false {
            if case .sheetDismissed = step.endCondition {
                // Complete tutorial - the completion animation will trigger
                // and after it finishes, coordinator.isActive will become false
                coordinator.advance()
            }
        }
    }

    private func handleDoubleTapCompleted() {
        guard let step = coordinator.currentStep else { return }

        if case .doubleTapCompleted = step.endCondition {
            _ = coordinator.checkEndCondition(.doubleTapCompleted)
        }
    }

    /// Handle selection changes during transition - prevents accidental selections before tutorial is ready
    private func handleSelectionChangeDuringTransition(from oldValue: DateItem?, to newValue: DateItem?) {
        // Only apply this safety check during the scrubbing step and before transition is complete
        guard !isTransitionComplete,
              let step = coordinator.currentStep,
              step.type == .scrubbing,
              newValue != nil,
              !isScrubbing else { return }

        // User somehow selected an entry during transition (shouldn't happen with gesture blocking,
        // but this is a safety net). Clear selection and re-scroll to today.
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                mockStore.clearSelection()
            }
            // Re-scroll to today's entry after dismissing the bottom view
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                hasScrolledToEntry = false
                scrollToTodayEntry()
            }
        }
    }

    private func handleScrubbingChange(from oldValue: Bool, to newValue: Bool) {
        guard let step = coordinator.currentStep else { return }

        // Scrubbing ended
        if oldValue == true && newValue == false {
            if case .scrubEnded = step.endCondition {
                // Small delay to let selection happen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    coordinator.advance()
                }
            }
        }
    }

    private func handleGridTap(at location: CGPoint, geometry: GeometryProxy) {
        if isScrubbing { return }

        guard let itemId = getItemId(at: location, geometry: geometry),
              let item = getItem(from: itemId) else { return }

        mockStore.selectDate(item.date)
        Haptic.play()
    }

    private func handlePinchGesture(value: MagnificationGesture.Value) {
        let scaleThreshold: CGFloat = 0.9
        let expandThreshold: CGFloat = 1.2

        // Pinch in: switch from "now" to "year" mode
        if value < scaleThreshold && mockStore.viewMode == .now {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                mockStore.viewMode = .year
            }
        }
        // Pinch out: switch from "year" to "now" mode
        else if value > expandThreshold && mockStore.viewMode == .year {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                mockStore.viewMode = .now
            }
        }
    }

    // MARK: - Helper Methods

    private func calculateSpacing(containerWidth: CGFloat, viewMode: ViewMode) -> CGFloat {
        let gridWidth = containerWidth - (2 * GRID_HORIZONTAL_PADDING)
        let totalDotsWidth = viewMode.dotSize * CGFloat(viewMode.dotsPerRow)
        let availableSpace = gridWidth - totalDotsWidth
        let spacing = availableSpace / CGFloat(viewMode.dotsPerRow - 1)
        let minimumSpacing: CGFloat = viewMode == .now ? 4 : 2
        return max(minimumSpacing, spacing)
    }

    /// Get item ID at a location - matches ContentView's implementation
    /// Location is relative to YearGridView (from LongPressScrubRecognizer overlay)
    private func getItemId(at location: CGPoint, geometry: GeometryProxy) -> String? {
        let gridWidth = geometry.size.width
        let spacing = calculateSpacing(containerWidth: gridWidth, viewMode: mockStore.viewMode)

        // Adjust for horizontal padding (location is relative to YearGridView which has padding)
        let adjustedX = location.x - GRID_HORIZONTAL_PADDING
        // Account for dot centering: half spacing + half dot size
        let adjustedY = location.y + (spacing / 2) + (mockStore.viewMode.dotSize / 2)

        let containerWidth = gridWidth - (2 * GRID_HORIZONTAL_PADDING)
        let totalSpacingWidth = CGFloat(mockStore.viewMode.dotsPerRow - 1) * spacing
        let totalDotWidth = containerWidth - totalSpacingWidth
        let itemSpacing = totalDotWidth / CGFloat(mockStore.viewMode.dotsPerRow)
        let startX = itemSpacing / 2

        let rowHeight = mockStore.viewMode.dotSize + spacing
        let row = max(0, Int(floor(adjustedY / rowHeight)))

        // Find closest column by distance (same as ContentView legacy method)
        var closestCol = 0
        var minDistance = CGFloat.greatestFiniteMagnitude

        for col in 0..<mockStore.viewMode.dotsPerRow {
            let xPos = startX + CGFloat(col) * (itemSpacing + spacing)
            let distance = abs(adjustedX - xPos)
            if distance < minDistance {
                minDistance = distance
                closestCol = col
            }
        }

        let col = max(0, min(mockStore.viewMode.dotsPerRow - 1, closestCol))
        let itemIndex = row * mockStore.viewMode.dotsPerRow + col

        guard itemIndex >= 0 && itemIndex < mockStore.itemsInYear.count else { return nil }
        return mockStore.itemsInYear[itemIndex].id
    }

    private func getItem(from itemId: String) -> DateItem? {
        return mockStore.itemsInYear.first { $0.id == itemId }
    }

    private func getTodayIndex() -> Int {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)

        guard mockStore.selectedYear == currentYear,
              let startOfYear = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) else {
            return 0
        }

        return calendar.dateComponents([.day], from: startOfYear, to: today).day ?? 0
    }

    /// Convert mock entries to DayEntry format for YearGridView compatibility
    private func mockEntriesToDayEntries() -> [DayEntry] {
        mockStore.entries.map { mockEntry in
            DayEntry(
                body: mockEntry.body,
                createdAt: mockEntry.date,
                drawingData: mockEntry.drawingData
            )
        }
    }
}

// MARK: - Sheet Tutorial Overlay (for non-Dynamic Island devices)

/// A simplified tutorial overlay for use inside sheets
private struct SheetTutorialOverlay: View {
    let tooltip: TutorialTooltip

    private let dimOpacity: Double = 0.15

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // No dim overlay - keep canvas fully visible

                // Tooltip at bottom of sheet, below the canvas
                VStack {
                    Spacer()

                    // Tooltip bubble
                    Text(tooltip.message)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                              .fill(Color.appAccent.opacity(0.8))
                        )
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Tutorial Header View (Year Only)

/// Custom header view for tutorial that only shows year selector (not date)
private struct TutorialHeaderView: View {
    @ObservedObject var mockStore: MockDataStore
    let geometry: GeometryProxy
    let highlightedItemId: String?
    let entries: [DayEntry]

    private let drawingSize: CGFloat = 52.0

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return [currentYear, currentYear + 1]
    }

    /// Get the highlighted DateItem from the mock store's items
    private var highlightedItem: DateItem? {
        guard let id = highlightedItemId else { return nil }
        return mockStore.itemsInYear.first { $0.id == id }
    }

    /// Get the entry for the highlighted item
    private var highlightedEntry: DayEntry? {
        guard let item = highlightedItem else { return nil }
        return entries.first { $0.matches(date: item.date) }
    }

    private var dotColor: Color {
        guard let highlightedItem else { return .textColor }
        let isHighlightedToday = Calendar.current.isDate(highlightedItem.date, inSameDayAs: Date())
        return isHighlightedToday ? .appAccent : .textColor
    }

    private var hasDrawing: Bool {
        guard let entry = highlightedEntry else { return false }
        return entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: geometry.safeAreaInsets.top)

            HStack {
                HStack(spacing: hasDrawing ? 12 : 6) {
                    // Year selector - shows only year, not date
                    Menu {
                        ForEach(availableYears, id: \.self) { year in
                            Button(String(year)) {
                                withAnimation {
                                    mockStore.selectedYear = year
                                }
                            }
                        }
                    } label: {
                        Text(String(mockStore.selectedYear))
                            .font(.title.bold())
                            .foregroundColor(.textColor)
                    }
                    .menuStyle(.borderlessButton)
                    .tutorialHighlightAnchor(.yearSelector)

                    // Show highlighted entry drawing/dot when scrubbing
                    if let entry = highlightedEntry {
                        if entry.drawingData != nil && !(entry.drawingData?.isEmpty ?? false) {
                            // Create a layout placeholder that doesn't affect HStack height
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    DrawingDisplayView(
                                        entry: entry,
                                        displaySize: drawingSize,
                                        dotStyle: .present,
                                        accent: true,
                                        highlighted: false,
                                        scale: 1.0,
                                        useThumbnail: true
                                    )
                                    .frame(width: drawingSize, height: drawingSize)
                                    .animation(.interactiveSpring, value: highlightedEntry)
                                )
                        } else if !entry.body.isEmpty {
                            ZStack {
                                // Dot
                                Circle()
                                    .fill(dotColor)
                                    .frame(width: 12, height: 12)

                                // Ring
                                Circle()
                                    .stroke(dotColor, lineWidth: 2)
                                    .frame(width: 18, height: 18)
                            }
                            .frame(width: 36, height: 36)
                            .animation(.interactiveSpring, value: highlightedEntry)
                        }
                    }
                }

                Spacer()

                // View mode toggle button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        mockStore.viewMode = mockStore.viewMode == .now ? .year : .now
                    }
                } label: {
                    Image(systemName: mockStore.viewMode == .now
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                }
                .circularGlassButton()
                .tutorialHighlightAnchor(.viewModeButton)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 50)
        }
        .background(headerBackground)
        .ignoresSafeArea(edges: .top)
    }

    private var headerBackground: some View {
        ZStack {
            Rectangle().fill(Color.backgroundColor)

            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.black.opacity(1.0), location: 0.0),
                    .init(color: Color.black.opacity(0.0), location: 0.4),
                    .init(color: Color.black.opacity(0.0), location: 1.0),
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

// MARK: - Previews

#Preview("Full Tutorial Flow") {
    let viewModel = OnboardingViewModel()
    return InteractiveTutorialView(viewModel: viewModel)
}

#Preview("Single Step - Scrubbing") {
    let viewModel = OnboardingViewModel()
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .scrubbing
    )
}

#Preview("Single Step - Open Canvas") {
    let viewModel = OnboardingViewModel()
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .drawAndEdit
    )
}

#Preview("Single Step - View Mode") {
    let viewModel = OnboardingViewModel()
    return InteractiveTutorialView(
        viewModel: viewModel,
        singleStepMode: true,
        startingStepType: .switchViewMode
    )
}
