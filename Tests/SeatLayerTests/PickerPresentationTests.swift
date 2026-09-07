import Combine
import XCTest
@testable import SeatLayer

@MainActor
final class PickerPresentationTests: XCTestCase {
    func testNewestUnansweredSeatIsExcludedUntilLocalConfirmation() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(controller: controller)

        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        XCTAssertEqual(presentation.pendingSeat?.label, "A-1")
        presentation.confirmPending()
        XCTAssertNil(presentation.pendingSeat)

        controller.accept(snapshot: snapshot(revision: 2, labels: ["A-1", "A-2"]))
        XCTAssertEqual(presentation.pendingSeat?.label, "A-2")
        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1"])
        XCTAssertFalse(presentation.canCheckout)

        presentation.confirmPending()
        XCTAssertNil(presentation.pendingSeat)
        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1", "A-2"])
        XCTAssertTrue(presentation.canCheckout)
    }

    func testSalesClosureDisablesCheckoutPromptsAndNewInventoryMutation() async {
        let transport = PresentationTransportSpy()
        let controller = readyController(
            transport: transport,
            commands: ["picker.bestAvailable", "picker.setTableQuantity"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )

        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: ["A-1"],
            salesClosed: true
        ))

        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1"])
        XCTAssertFalse(presentation.canCheckout)
        XCTAssertFalse(presentation.canUseBestAvailable)
        controller.accept(generalAdmissionCandidate: GAArea(id: "ga-1", label: "Standing"))
        XCTAssertNil(presentation.activePrompt)
        do {
            _ = try await presentation.setTableQuantity(label: "Table 1", quantity: 4)
            XCTFail("sales-closed table mutation should fail")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "sales_closed")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let calls = await transport.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testTierMutationPrecedesLocalConfirmationAndUpdatesCartTruth() async throws {
        let tiers: [JSONValue] = [
            ["id": "adult", "name": "Adult", "price": 100, "currency": "EUR"],
            ["id": "child", "name": "Child", "price": 60, "currency": "EUR"],
        ]
        let transport = PresentationTransportSpy(
            responses: [
                "picker.setSeatTier": ["snapshot": snapshot(
                    revision: 3,
                    labels: ["G-1"],
                    seatPrice: 60,
                    tierId: "child",
                    tiers: tiers
                )],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.setSeatTier"]
        )
        let presentation = SeatLayerPickerPresentationModel(controller: controller)
        var selected: [SelectedSeat] = []
        let selectionCancellable = presentation.seatSelections.sink { selected.append($0) }
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: ["G-1"],
            seatPrice: 100,
            tierId: "adult",
            tiers: tiers
        ))

        XCTAssertEqual(presentation.pendingSeat?.tierId, "adult")
        XCTAssertEqual(presentation.pendingTierId, "adult")
        presentation.choosePendingTier("child")
        // Panorama/3D state can advance the authoritative snapshot while the
        // unanswered confirmation view is temporarily absent. The local tier
        // decision must survive that renderer-owned inspection round trip.
        controller.accept(snapshot: snapshot(
            revision: 2,
            labels: ["G-1"],
            buyerView: "venue3d",
            seatPrice: 100,
            tierId: "adult",
            tiers: tiers
        ))
        XCTAssertEqual(presentation.pendingTierId, "child")
        let callsBeforeConfirmation = await transport.recordedCalls()
        XCTAssertTrue(callsBeforeConfirmation.isEmpty)

        let confirmed = await presentation.confirmPending(tierId: nil)
        XCTAssertTrue(confirmed)
        XCTAssertNil(presentation.pendingSeat)
        XCTAssertEqual(presentation.confirmedCartLines.first?.tierId, "child")
        XCTAssertEqual(presentation.confirmedCartLines.first?.unitPrice, 60)
        XCTAssertEqual(presentation.selectionFlight?.seatId, "seat-1")
        XCTAssertEqual(presentation.selectionFlight?.label, "G-1")
        XCTAssertEqual(selected.first?.tierId, "child")
        XCTAssertEqual(selected.first?.price, 60)
        _ = selectionCancellable

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.setSeatTier"])
        XCTAssertEqual(calls.first?.payload, ["seatId": "seat-1", "tierId": "child"])
    }

    func testPresentationCheckoutIsSingleFlightThroughTheHostCallback() async throws {
        let transport = PresentationTransportSpy(
            responses: ["picker.continue": checkoutResponse()],
            delayNanoseconds: 30_000_000
        )
        let controller = readyController(transport: transport, commands: ["picker.continue"])
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        XCTAssertTrue(presentation.canCheckout)

        var callbackCount = 0
        var continued: [SeatLayerPickerCheckoutHandoff] = []
        let continueCancellable = presentation.checkoutContinuations.sink { continued.append($0) }
        let handler: SeatLayerPickerCheckoutHandler = { _ in
            callbackCount += 1
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        async let first = presentation.checkout(using: handler)
        async let second = presentation.checkout(using: handler)
        let handoffs = try await [first, second]
        let calls = await transport.recordedCalls()

        XCTAssertEqual(handoffs.map(\.holdId), ["opaque-test-hold", "opaque-test-hold"])
        XCTAssertEqual(callbackCount, 1)
        XCTAssertEqual(continued.map(\.holdId), ["opaque-test-hold"])
        XCTAssertEqual(calls.map(\.name), ["picker.continue"])
        XCTAssertEqual(presentation.checkoutHandoff?.holdId, "opaque-test-hold")
        XCTAssertFalse(presentation.canCheckout)
        _ = continueCancellable
    }

    func testRemovalInspectionAndClosePublishOnlyAcceptedNativeActions() async throws {
        let transport = PresentationTransportSpy(
            responses: [
                "picker.removeCartLine": ["snapshot": snapshot(revision: 2, labels: [])],
                "picker.abort": [:],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.removeCartLine", "picker.abort"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        let seat = try XCTUnwrap(controller.snapshot?.selection.first)
        var removals: [String] = []
        var inspections: [SelectedSeat] = []
        var closures: [SeatLayerPickerCloseReason] = []
        var cancellables: Set<AnyCancellable> = []
        presentation.seatRemovals.sink { removals.append($0) }.store(in: &cancellables)
        presentation.seatViewOpenings.sink { inspections.append($0) }.store(in: &cancellables)
        presentation.closures.sink { closures.append($0) }.store(in: &cancellables)

        try await presentation.removeCartLine("A-1")
        presentation.recordSeatViewOpened(seat)
        var hostCloseCount = 0
        await presentation.close(using: { hostCloseCount += 1 }, reason: .systemBack)
        await presentation.close(using: { hostCloseCount += 1 }, reason: .programmatic)

        XCTAssertEqual(removals, ["A-1"])
        XCTAssertEqual(inspections.map(\.label), ["A-1"])
        XCTAssertEqual(closures, [.systemBack])
        XCTAssertEqual(hostCloseCount, 1)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "picker.removeCartLine", "picker.abort",
        ])
    }

    func testSuccessfulRemovalOffersExactSameSessionUndo() async throws {
        let transport = PresentationTransportSpy(
            responses: [
                "picker.removeCartLine": ["snapshot": snapshot(revision: 2, labels: [])],
                "picker.selectObjects": ["snapshot": snapshot(revision: 3, labels: ["A-1"])],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.removeCartLine", "picker.selectObjects"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        controller.record(.bridge(.init(code: "sold_out", message: "stale attempt")))
        XCTAssertEqual(presentation.lastActionError?.code, "sold_out")

        try await presentation.removeCartLine("A-1")
        XCTAssertNil(presentation.lastActionError)
        XCTAssertEqual(presentation.removalUndo?.sessionId, "session-test")
        XCTAssertEqual(presentation.removalUndo?.labels, ["A-1"])
        XCTAssertTrue(presentation.canUndoRemoval)

        let didUndo = try await presentation.undoRemoval()
        XCTAssertTrue(didUndo)
        XCTAssertNil(presentation.removalUndo)
        XCTAssertEqual(controller.snapshot?.cartLines.map(\.label), ["A-1"])
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.removeCartLine", "picker.selectObjects"])
        XCTAssertEqual(calls.last?.payload, ["objects": ["A-1"]])
    }

    func testUndoRestoresTheRuntimeAcceptedTicketTierBeforeClearingUndo() async throws {
        let tiers: [JSONValue] = [
            ["id": "adult", "name": "Adult", "price": 100, "currency": "EUR"],
            ["id": "child", "name": "Child", "price": 60, "currency": "EUR"],
        ]
        let transport = PresentationTransportSpy(
            responses: [
                "picker.removeCartLine": ["snapshot": snapshot(revision: 2, labels: [])],
                "picker.selectObjects": ["snapshot": snapshot(
                    revision: 3,
                    labels: ["A-1"],
                    seatPrice: 100,
                    tierId: "adult",
                    tiers: tiers
                )],
                "picker.setSeatTier": ["snapshot": snapshot(
                    revision: 4,
                    labels: ["A-1"],
                    seatPrice: 60,
                    tierId: "child",
                    tiers: tiers
                )],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.removeCartLine", "picker.selectObjects", "picker.setSeatTier"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: ["A-1"],
            seatPrice: 60,
            tierId: "child",
            tiers: tiers
        ))

        try await presentation.removeCartLine("A-1")
        let didUndo = try await presentation.undoRemoval()
        XCTAssertTrue(didUndo)
        XCTAssertNil(presentation.removalUndo)
        XCTAssertEqual(controller.snapshot?.cartLines.first?.tierId, "child")
        XCTAssertEqual(controller.snapshot?.cartLines.first?.unitPrice, 60)

        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "picker.removeCartLine", "picker.selectObjects", "picker.setSeatTier",
        ])
        XCTAssertEqual(calls.last?.payload, ["seatId": "seat-1", "tierId": "child"])
    }

    func testReadOnlyAndHostOwnedCartsRejectNativeMutationBeforeTransport() async {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: ["picker.removeCartLine"])
        let readOnly = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(readOnly: true, confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        XCTAssertFalse(readOnly.canMutateCart)
        do {
            try await readOnly.removeCartLine("A-1")
            XCTFail("read-only mutation should fail")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "read_only")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        var hostOwnedRaw = snapshot(revision: 2, labels: ["A-1"]).objectValue ?? [:]
        hostOwnedRaw["hold"] = ["active": true, "ownership": "host"]
        controller.accept(snapshot: .object(hostOwnedRaw))
        let hostOwned = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        XCTAssertFalse(hostOwned.canMutateCart)
        do {
            try await hostOwned.removeCartLine("A-1")
            XCTFail("host-owned mutation should fail")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "hold_owned_by_host")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
        let calls = await transport.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func testHostRejectionReleasesTheExactHandoffAndDoesNotRetainIt() async {
        let transport = PresentationTransportSpy(
            responses: [
                "picker.continue": checkoutResponse(),
                "picker.rejectHandoff": [:],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "picker.rejectHandoff"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        var continued: [SeatLayerPickerCheckoutHandoff] = []
        let continueCancellable = presentation.checkoutContinuations.sink { continued.append($0) }

        do {
            _ = try await presentation.checkout { _ in throw HostDeclinedCheckout.example }
            XCTFail("expected the host rejection to surface")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "sl_transport")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        XCTAssertNil(presentation.checkoutHandoff)
        XCTAssertFalse(presentation.actionInFlight)
        XCTAssertEqual(continued.map(\.holdId), ["opaque-test-hold"])
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.continue", "picker.rejectHandoff"])
        XCTAssertEqual(calls.last?.payload, ["holdId": "opaque-test-hold"])
        _ = continueCancellable
    }

    func testBackConsumesPromptCartConfirmation3DTargetOverviewThenHost() async {
        let targetedMap: [String: JSONValue] = [
            "view3dTargetSeatId": "seat-1",
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": .null,
            "view3dFocusedSectionId": "section-a",
        ]
        let overviewMap: [String: JSONValue] = [
            "view3dPreviousSeatId": .null,
            "view3dNextSeatId": .null,
            "view3dFocusedSectionId": .null,
        ]
        let transport = PresentationTransportSpy(
            responses: [
                "picker.deselectObjects": ["snapshot": snapshot(
                    revision: 5,
                    labels: [],
                    buyerView: "map"
                )],
                "picker.abort": ["snapshot": snapshot(revision: 6, labels: [])],
            ],
            responseSequences: [
                "picker.setBuyerView": [
                    ["snapshot": snapshot(
                        revision: 3,
                        labels: ["A-1"],
                        buyerView: "venue3d",
                        mapAdditions: overviewMap
                    )],
                    ["snapshot": snapshot(revision: 4, labels: ["A-1"])],
                ],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.deselectObjects", "picker.setBuyerView", "picker.abort"],
            capabilities: ["venue-3d-v1"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(panelInitiallyCollapsed: false)
        )
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: ["A-1"],
            buyerView: "venue3d",
            mapAdditions: targetedMap
        ))
        controller.accept(generalAdmissionCandidate: GAArea(id: "ga-1", label: "Standing"))

        var steps: [SeatLayerPickerBackStep] = []
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        steps.append(await presentation.back())
        XCTAssertEqual(presentation.pendingSeat?.label, "A-1")
        steps.append(await presentation.back())
        XCTAssertEqual(presentation.pendingSeat?.label, "A-1")
        steps.append(await presentation.back())
        XCTAssertNil(presentation.pendingSeat)
        var hostCloseCount = 0
        steps.append(await presentation.back { hostCloseCount += 1 })

        XCTAssertEqual(steps, [.prompt, .cart, .venue, .venue, .confirmation, .close])
        XCTAssertEqual(hostCloseCount, 1)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), [
            "picker.setBuyerView", "picker.setBuyerView", "picker.deselectObjects", "picker.abort",
        ])
        XCTAssertEqual(calls[0].payload, ["view": "venue3d", "resetView": true])
        XCTAssertEqual(calls[1].payload, ["view": "map"])
        XCTAssertEqual(calls[2].payload, ["objects": ["A-1"]])
    }

    func testBackWalksOne2DMapRungAtATime() async {
        let transport = PresentationTransportSpy(
            responses: ["picker.abort": ["snapshot": snapshot(revision: 4, labels: [])]],
            responseSequences: [
                "picker.zoomOut": [
                    ["snapshot": snapshot(revision: 2, labels: [], rung: "sections")],
                    ["snapshot": snapshot(revision: 3, labels: [], rung: "zones")],
                ],
            ]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.zoomOut", "picker.abort"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false, panelInitiallyCollapsed: true)
        )
        controller.accept(snapshot: snapshot(
            revision: 1,
            labels: [],
            focused: true,
            rung: "seats"
        ))

        var hostCloseCount = 0
        let steps = [
            await presentation.back(),
            await presentation.back(),
            await presentation.back { hostCloseCount += 1 },
        ]

        XCTAssertEqual(steps, [.section, .section, .close])
        XCTAssertEqual(hostCloseCount, 1)
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.zoomOut", "picker.zoomOut", "picker.abort"])
    }

    func testASecondTapOnAnAnsweredSeatAsksBeforeItRemoves() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(controller: controller)

        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        presentation.confirmPending()
        let seat = try XCTUnwrap(controller.snapshot?.selection.first)

        controller.accept(seatRetap: seat)
        XCTAssertEqual(presentation.candidateSeat?.label, "A-1")
        XCTAssertEqual(presentation.cardIntent, .remove)
        // A seat the buyer already agreed to stays counted while the card asks.
        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1"])

        presentation.dismissCandidate()
        XCTAssertNil(presentation.candidateSeat)
        XCTAssertEqual(presentation.cardIntent, .add)
    }

    func testACandidateTheBuyerHasNotAgreedToIsNotCounted() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )

        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1", "A-2"]))
        let seat = try XCTUnwrap(controller.snapshot?.selection.last)
        presentation.askAbout(seat)

        XCTAssertEqual(presentation.cardIntent, .add)
        XCTAssertEqual(presentation.confirmedCartLines.map(\.label), ["A-1"])
        XCTAssertEqual(presentation.confirmedTicketCount, 1)
        XCTAssertEqual(presentation.confirmedCartTotal, 25)
    }

    func testTheSheetStepsDownUnderACardAndBackWhenItGoes() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(panelInitiallyCollapsed: false)
        )

        XCTAssertEqual(presentation.sheetDetent, .open)
        XCTAssertTrue(presentation.cartSheetExpanded)

        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        presentation.askAbout(try XCTUnwrap(controller.snapshot?.selection.first))
        XCTAssertEqual(presentation.sheetDetent, .mini)
        XCTAssertFalse(presentation.cartSheetExpanded)

        presentation.dismissCandidate()
        XCTAssertEqual(presentation.sheetDetent, .peek)

        presentation.cartSheetExpanded = true
        XCTAssertEqual(presentation.sheetDetent, .open)
        XCTAssertEqual(presentation.nextBackStep, .cart)
    }

    func testTheAddLandsBeforeAnythingElseMoves() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(controller: controller)

        XCTAssertTrue(presentation.mapMayMove)
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        presentation.confirmPending()

        XCTAssertEqual(presentation.cartLanding, .cardDismissed)
        XCTAssertFalse(presentation.mapMayMove)
        presentation.chipDidLand()
        XCTAssertEqual(presentation.cartLanding, .chipLanded)
        XCTAssertFalse(presentation.mapMayMove)
        presentation.endCartLanding()
        XCTAssertEqual(presentation.cartLanding, .mapMayMove)
        XCTAssertTrue(presentation.mapMayMove)
    }

    func testSeatsAHoldArrivesWithAreAdoptedAndLaterTapsStillAsk() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(controller: controller)

        var held = try XCTUnwrap(snapshot(revision: 1, labels: ["A-1", "A-2"]).objectValue)
        held["hold"] = ["active": true, "ownership": "picker"]
        controller.accept(snapshot: .object(held))

        // A hold agreed to before this picker opened is not a question.
        XCTAssertNil(presentation.pendingSeat)
        XCTAssertEqual(presentation.confirmedCartLines.count, 2)

        var later = try XCTUnwrap(
            snapshot(revision: 2, labels: ["A-1", "A-2", "A-3"]).objectValue
        )
        later["hold"] = ["active": true, "ownership": "picker"]
        controller.accept(snapshot: .object(later))
        XCTAssertEqual(presentation.pendingSeat?.label, "A-3")
    }

    func testSeatsPickedSinceTheHoldAreCountedForTheCheckoutButton() throws {
        let transport = PresentationTransportSpy()
        let controller = readyController(transport: transport, commands: [])
        let presentation = SeatLayerPickerPresentationModel(controller: controller)

        var held = try XCTUnwrap(snapshot(revision: 1, labels: ["A-1", "A-2"]).objectValue)
        held["hold"] = ["active": true, "ownership": "picker"]
        controller.accept(snapshot: .object(held))
        // The cart the hold was made from is not "picked since".
        XCTAssertEqual(presentation.pendingCount, 0)

        var later = try XCTUnwrap(
            snapshot(revision: 2, labels: ["A-1", "A-2", "A-3", "A-4"]).objectValue
        )
        later["hold"] = ["active": true, "ownership": "picker"]
        controller.accept(snapshot: .object(later))
        XCTAssertEqual(presentation.pendingCount, 2)

        // The hold goes and there is nothing left to fold into it.
        controller.accept(snapshot: snapshot(revision: 3, labels: ["A-1", "A-2", "A-3"]))
        XCTAssertEqual(presentation.pendingCount, 0)
    }

    func testTheButtonSaysOpeningCheckoutOnlyWhileTheHostIsRunning() async throws {
        let strings = SeatLayerPickerStrings(localeIdentifier: "en")
        let securing = seatLayerCheckoutCtaState(
            SeatLayerPickerCheckoutCtaInput(
                label: "Hold seats",
                canCheckout: false,
                creatingHold: true,
                ticketCount: 2
            ),
            strings: strings
        )
        XCTAssertEqual(securing.label, strings.text(.securingSeats))
        XCTAssertTrue(securing.busy)

        let opening = seatLayerCheckoutCtaState(
            SeatLayerPickerCheckoutCtaInput(
                label: "Hold seats",
                canCheckout: false,
                handoffInFlight: true,
                ticketCount: 2
            ),
            strings: strings
        )
        XCTAssertEqual(opening.label, strings.text(.openingCheckout))
        XCTAssertTrue(opening.busy)

        let more = seatLayerCheckoutCtaState(
            SeatLayerPickerCheckoutCtaInput(
                label: "Hold seats",
                canCheckout: true,
                ticketCount: 4,
                pendingCount: 2,
                holdActive: true
            ),
            strings: strings
        )
        XCTAssertEqual(
            more.label,
            strings.text(.secureMoreAndCheckout, replacing: ["count": "2"])
        )
        XCTAssertTrue(more.enabled)
    }

    func testCheckoutCanResumeAfterTheHostHandsTheBuyerBack() async throws {
        let transport = PresentationTransportSpy(
            responses: ["picker.continue": checkoutResponse()]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue"]
        )
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))

        _ = try await presentation.checkout { _ in }
        XCTAssertNotNil(presentation.checkoutHandoff)
        XCTAssertFalse(presentation.canCheckout)

        presentation.resumeAfterCheckout()
        XCTAssertTrue(presentation.resumedAfterCheckout)
        XCTAssertTrue(presentation.canCheckout)
    }

    func testCheckoutReplacesAMismatchedHoldAndAsksAgain() async throws {
        let transport = PresentationTransportSpy(
            responses: ["picker.continue": checkoutResponse(), "hold": [:]],
            failOnce: ["picker.continue": .bridge(.init(
                code: "hold_selection_mismatch",
                message: "the hold does not match the selection"
            ))]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue", "hold"]
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))

        let handoff = try await controller.checkout()

        XCTAssertEqual(handoff.holdId, "opaque-test-hold")
        let calls = await transport.recordedCalls()
        XCTAssertEqual(calls.map(\.name), ["picker.continue", "hold", "picker.continue"])
    }

    func testAMismatchWithNoHoldCommandToReplaceItStillSurfaces() async {
        let transport = PresentationTransportSpy(
            failOnce: ["picker.continue": .bridge(.init(
                code: "hold_selection_mismatch",
                message: "the hold does not match the selection"
            ))]
        )
        let controller = readyController(
            transport: transport,
            commands: ["picker.continue"]
        )
        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))

        do {
            _ = try await controller.checkout()
            XCTFail("a mismatch with no way to replace the hold must surface")
        } catch let error as SeatLayerError {
            XCTAssertEqual(error.code, "hold_selection_mismatch")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    private func readyController(
        transport: PresentationTransportSpy,
        commands: [String],
        capabilities: [String] = []
    ) -> SeatLayerPickerController {
        let controller = SeatLayerPickerController(
            transport: transport,
            bundleInfo: BundleInfo([
                "bundle": "0.84.1",
                "protocol": ["min": 2, "max": 2],
                "capabilities": .array(capabilities.map(JSONValue.string)),
                "commands": .array(commands.map(JSONValue.string)),
                "events": .array(["picker.snapshot"]),
            ]),
            revisionWaitNanoseconds: 20_000_000
        )
        controller.markReady(
            ReadyInfo([
                "protocol": 2,
                "mode": "test",
                "transport": "ios",
                "chart": ["event": "event-test"],
            ]),
            payload: nil
        )
        return controller
    }

    /// The buyer came back from the host's checkout with the hold still theirs.
    ///
    /// `resumeAfterCheckout()` says so, and its whole point is that the action
    /// works again — a "Continue to checkout" that can never check out is a
    /// dead end for the rest of the session.
    func testComingBackFromCheckoutOpensTheTillAgain() async throws {
        let transport = PresentationTransportSpy(
            responses: ["picker.continue": checkoutResponse()]
        )
        let controller = readyController(transport: transport, commands: ["picker.continue"])
        let presentation = SeatLayerPickerPresentationModel(
            controller: controller,
            options: .init(confirmSelection: false)
        )

        controller.accept(snapshot: snapshot(revision: 1, labels: ["A-1"]))
        XCTAssertTrue(presentation.canCheckout)

        _ = try await presentation.checkout(using: { _ in })
        controller.accept(snapshot: snapshot(
            revision: 2,
            labels: ["A-1"],
            hold: ["active": true, "owner": "host"]
        ))
        XCTAssertFalse(presentation.canCheckout)

        presentation.resumeAfterCheckout()
        XCTAssertTrue(presentation.canCheckout)
    }

    private func snapshot(
        revision: Int,
        labels: [String],
        focused: Bool = false,
        buyerView: String = "map",
        rung: String = "zones",
        mapAdditions: [String: JSONValue] = [:],
        seatPrice: Int = 25,
        tierId: String? = nil,
        tiers: [JSONValue]? = nil,
        salesClosed: Bool = false,
        hold: [String: JSONValue] = ["active": false]
    ) -> JSONValue {
        let seats: [JSONValue] = labels.enumerated().map { index, label in
            var seat: [String: JSONValue] = [
                "id": .string("seat-\(index + 1)"),
                "label": .string(label),
                "objectId": .string("row-a"),
                "objectType": .string("seat"),
                "currency": .string("EUR"),
                "price": .int(seatPrice),
            ]
            if let tierId { seat["tierId"] = .string(tierId) }
            if let tiers { seat["tiers"] = .array(tiers) }
            return .object(seat)
        }
        let items: [JSONValue] = labels.enumerated().map { index, label in
            var item: [String: JSONValue] = [
                "lineKey": .string("line-\(index + 1)"),
                "label": .string(label),
                "objectId": .string("row-a"),
                "objectType": .string("seat"),
                "categoryKey": .string("standard"),
                "unitPrice": .int(seatPrice),
                "currency": .string("EUR"),
                "quantity": .int(1),
                "seatId": .string("seat-\(index + 1)"),
            ]
            if let tierId { item["tierId"] = .string(tierId) }
            return .object(item)
        }
        var map: [String: JSONValue] = [
            "rung": .string(rung),
            "buyerView": .string(buyerView),
        ]
        if focused { map["focusedSectionId"] = .string("section-a") }
        map.merge(mapAdditions) { _, value in value }
        return [
            "schema": .string(seatLayerPickerSnapshotSchema),
            "sessionId": "session-test",
            "revision": .int(revision),
            "event": [
                "key": "event-test",
                "name": "Opening Night",
                "mode": "test",
                "currency": "EUR",
                "salesClosed": .bool(salesClosed),
            ],
            "features": ["venue3d": true],
            "map": .object(map),
            "selection": [
                "seats": .array(seats),
                "validity": [
                    "isValid": true,
                    "count": .int(labels.count),
                    "required": .int(labels.count),
                    "remaining": 0,
                    "seats": .array(seats),
                    "violations": .array([]),
                ],
            ],
            "cart": [
                "currency": "EUR",
                "quantity": .int(labels.count),
                "total": .int(labels.count * seatPrice),
                "items": .array(items),
            ],
            "hold": .object(hold),
        ]
    }

    private func checkoutResponse() -> JSONValue {
        [
            "handoff": [
                "holdId": "opaque-test-hold",
                "expiresAt": 1_800_000_000_000,
                "currency": "EUR",
                "lineItems": .array([]),
                "total": 25,
            ],
        ]
    }
}

private enum HostDeclinedCheckout: Error {
    case example
}

private actor PresentationTransportSpy: SeatLayerPickerCommandTransport {
    struct Call: Sendable, Equatable {
        let name: String
        let payload: JSONValue?
    }

    private var calls: [Call] = []
    private let responses: [String: JSONValue]
    private let responseSequences: [String: [JSONValue]]
    private var responseOffsets: [String: Int] = [:]
    private let delayNanoseconds: UInt64

    private var failOnce: [String: SeatLayerError]

    init(
        responses: [String: JSONValue] = [:],
        responseSequences: [String: [JSONValue]] = [:],
        failOnce: [String: SeatLayerError] = [:],
        delayNanoseconds: UInt64 = 0
    ) {
        self.responses = responses
        self.responseSequences = responseSequences
        self.failOnce = failOnce
        self.delayNanoseconds = delayNanoseconds
    }

    func command(_ name: String, payload: JSONValue?) async throws -> JSONValue {
        calls.append(.init(name: name, payload: payload))
        if let failure = failOnce.removeValue(forKey: name) { throw failure }
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
        if let sequence = responseSequences[name] {
            let offset = responseOffsets[name, default: 0]
            if offset < sequence.count {
                responseOffsets[name] = offset + 1
                return sequence[offset]
            }
        }
        return responses[name] ?? [:]
    }

    func recordedCalls() -> [Call] { calls }
}

/// The public knobs a host sets, and the defaults each one carries.
final class PickerPublicOptionTests: XCTestCase {
    func testTheApprovedDefaultsAreTheOnesTheOwnerChose() {
        let options = SeatLayerPickerOptions()

        XCTAssertNil(options.eventName)
        XCTAssertTrue(options.showBookedOverlay)
        XCTAssertTrue(options.persistColorblindPreference)
        // The ticket panel already names the section the buyer is in.
        XCTAssertFalse(options.chrome.dock)
        XCTAssertTrue(options.chrome.seatCardGlass)
    }

    func testWideOnlyControlsStayOffThePhoneUntilAskedFor() {
        let defaults = SeatLayerPickerChromeOptions()

        for control in [
            defaults.showsFit(wide:),
            defaults.showsExtendHoldPrompt(wide:),
            defaults.showsOverview(wide:),
            defaults.showsZoom(wide:),
            defaults.showsColorblind(wide:),
        ] {
            XCTAssertTrue(control(true))
            XCTAssertFalse(control(false))
        }

        let asked = SeatLayerPickerChromeOptions(
            phoneOverview: true,
            phoneZoom: true,
            phoneColorblind: true,
            phoneFit: true
        )
        XCTAssertTrue(asked.showsFit(wide: false))
        XCTAssertTrue(asked.showsOverview(wide: false))
    }

    func testTheThemeCarriesTheOrganizerLookWithoutInventingOne() {
        let theme = SeatLayerPickerTheme(
            fontFamily: "Inter",
            logo: SeatLayerPickerBrandLogo(imageName: "brand"),
            radius: -4,
            buttonRadius: 6,
            layout: .init(overrides: ["peekHeight": 72])
        )

        XCTAssertEqual(theme.fontFamily, "Inter")
        XCTAssertEqual(theme.logo?.imageName, "brand")
        // A negative radius is not a shape.
        XCTAssertEqual(theme.radius, 0)
        XCTAssertEqual(theme.buttonRadius, 6)
        XCTAssertEqual(theme.layout?.value("peekHeight"), 72)
        // An untouched token still answers with the canonical value.
        XCTAssertEqual(
            theme.layout?.value("headerHeight"),
            SeatLayerPickerSizeTokens.headerHeight
        )
        XCTAssertNil(theme.layout?.value("aTokenThisBuildDoesNotKnow"))
        XCTAssertNil(SeatLayerPickerTheme().layout)
    }
}
