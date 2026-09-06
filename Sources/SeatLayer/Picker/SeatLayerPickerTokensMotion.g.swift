// GENERATED — do not edit.
//
// Source: Design/tokens.json
// Regenerate: node Scripts/generate-picker-tokens.mjs
//
// Motion durations, curves and the touch simulation.
import Foundation

/// Motion durations, in milliseconds.
public enum SeatLayerPickerMotionDurationTokens {
    /// Nothing in this namespace's in-budget durations may exceed this.
    public static let budgetMs = 420
    /// `260 ms`
    public static let enter = 260
    /// `180 ms`
    public static let exit = 180
    /// `240 ms`
    public static let dock = 240
    /// `300 ms`
    public static let sheet = 300
    /// `420 ms`
    public static let fly = 420
    /// `180 ms`
    public static let pop = 180
    /// `60 ms`
    public static let stagger = 60
    /// `120 ms`
    public static let crossfade = 120
    /// `240 ms`
    public static let bump = 240
    /// `240 ms`
    public static let chevron = 240
    /// `200 ms`
    public static let toast = 200
    /// `300 ms`
    public static let immersive = 300
    /// `360 ms`
    public static let pressSweep = 360
    /// `240 ms`
    public static let cardEnter = 240
    /// `160 ms`
    public static let thumbOut = 160
    /// `4000` ms — deliberately outside the budget.
    public static let undoWindow = 4000
    /// `300` ms — deliberately outside the budget.
    public static let inviteDelay = 300
    /// `700` ms — deliberately outside the budget.
    public static let inviteSweep = 700
    /// `1000` ms — deliberately outside the budget.
    public static let inviteBreatheDelay = 1000
    /// `2400` ms — deliberately outside the budget.
    public static let inviteBreathe = 2400
    /// `500` ms — deliberately outside the budget.
    public static let confirmFlight = 500
    /// `4200` ms — deliberately outside the budget.
    public static let toastDwell = 4200
    /// `900` ms — deliberately outside the budget.
    public static let revealDelay = 900
    /// `650` ms — deliberately outside the budget.
    public static let shellSweep = 650

    /// The durations inside the budget, keyed by token name.
    public static let inBudget: [String: Int] = [
        "enter": enter,
        "exit": exit,
        "dock": dock,
        "sheet": sheet,
        "fly": fly,
        "pop": pop,
        "stagger": stagger,
        "crossfade": crossfade,
        "bump": bump,
        "chevron": chevron,
        "toast": toast,
        "immersive": immersive,
        "pressSweep": pressSweep,
        "cardEnter": cardEnter,
        "thumbOut": thumbOut,
    ]

    /// The durations deliberately outside the budget, keyed by token name.
    public static let outsideBudget: [String: Int] = [
        "undoWindow": undoWindow,
        "inviteDelay": inviteDelay,
        "inviteSweep": inviteSweep,
        "inviteBreatheDelay": inviteBreatheDelay,
        "inviteBreathe": inviteBreathe,
        "confirmFlight": confirmFlight,
        "toastDwell": toastDwell,
        "revealDelay": revealDelay,
        "shellSweep": shellSweep,
    ]

    /// What the picker does when the viewer asks for less movement.
    public static let reducedMotionPolicy = "Every duration collapses to 0 ms when the viewer asks for less movement; motion with no reduced form (fly-to-tray, staggered arrival) is skipped rather than played instantly."
}

/// What a finger on glass is answered with.
/// 
/// Native-only: the web picker has no simulation to feed.
public enum SeatLayerPickerPhysicsTokens {
    /// `1`
    public static let sheetSpringMass: Double = 1
    /// `420`
    public static let sheetSpringStiffness: Double = 420
    /// `34`
    public static let sheetSpringDamping: Double = 34
    /// `320`
    public static let sheetFlingVelocity: Double = 320
    /// `0.35`
    public static let rubberBand: Double = 0.35
    /// `0.4`
    public static let swipeCommitFraction: Double = 0.4
    /// `700`
    public static let swipeFlingVelocity: Double = 700

    /// Every constant in the simulation, keyed by its token name.
    public static let all: [String: Double] = [
        "sheetSpringMass": sheetSpringMass,
        "sheetSpringStiffness": sheetSpringStiffness,
        "sheetSpringDamping": sheetSpringDamping,
        "sheetFlingVelocity": sheetFlingVelocity,
        "rubberBand": rubberBand,
        "swipeCommitFraction": swipeCommitFraction,
        "swipeFlingVelocity": swipeFlingVelocity,
    ]
}

/// The cubic-Bézier curves the picker animates along.
public enum SeatLayerPickerCurveTokens {
    /// `cubic 0.34, 1.56, 0.64, 1`
    public static let spring = SeatLayerPickerCubicBezier(
        x1: 0.34, y1: 1.56,
        x2: 0.64, y2: 1
    )
    /// `cubic 0.2, 0.8, 0.2, 1`
    public static let easeEnter = SeatLayerPickerCubicBezier(
        x1: 0.2, y1: 0.8,
        x2: 0.2, y2: 1
    )
    /// `cubic 0.4, 0, 1, 1`
    public static let easeExit = SeatLayerPickerCubicBezier(
        x1: 0.4, y1: 0,
        x2: 1, y2: 1
    )

    /// Every curve, keyed by its token name.
    public static let all: [String: SeatLayerPickerCubicBezier] = [
        "spring": spring,
        "easeEnter": easeEnter,
        "easeExit": easeExit,
    ]
}
