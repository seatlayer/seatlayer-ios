import UIKit
import SeatLayer

/// Loads a chart, shows live selection state, and drives a few commands.
///
/// Layout note: the map gets a FIXED-HEIGHT box and the status panel sits below
/// it. That is the supported v0.1 arrangement — the map is never inside a
/// scroll view.
final class DemoViewController: UIViewController {

    private let mapView = SeatLayerView()
    private let statusLabel = UILabel()
    private let selectionLabel = UILabel()
    private let modeBadge = UILabel()
    private let holdButton = UIButton(type: .system)
    private let bestAvailableButton = UIButton(type: .system)
    private let zoomButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        title = "SeatLayer"
        buildUI()

        mapView.delegate = self
        Task { await start() }
    }

    // MARK: - Boot

    private func start() async {
        var configuration = SeatLayerConfiguration(event: "ev_ios_demo", currency: "USD")
        configuration.hostInfo = ["app": "SeatLayerDemo/1.0"]

        // Point the WebView at the offline fixture page shipped with this demo.
        // A production app omits this and gets the SDK's bundled shell, which
        // renders the real event named by `configuration.event`.
        if let fixture = Bundle.main.url(forResource: "demo", withExtension: "html") {
            configuration.pageURL = fixture
        }

        log("loading…")
        do {
            let info = try await mapView.load(configuration)
            // The single most important line in this file for a real integration:
            // this is the proof the handshake completed.
            NSLog("[SeatLayerDemo] sys.ready protocol=\(info.protocolRevision) mode=\(info.mode.rawValue) transport=\(info.transport.rawValue) event=\(info.eventKey ?? "-")")
            log("ready · protocol \(info.protocolRevision) · transport \(info.transport.rawValue)")
            showModeBadge(info.mode)

            if let bundle = mapView.bundleInfo {
                NSLog("[SeatLayerDemo] bundle=\(bundle.bundle) protocol=\(bundle.protocolRange.min)...\(bundle.protocolRange.max) commands=\(bundle.commands.count) events=\(bundle.events.count)")
            }

            // Exercise a couple of round-trips so the demo proves cmd→res, not
            // just the handshake.
            let floors = try await mapView.getFloors()
            NSLog("[SeatLayerDemo] getFloors -> \(floors.map(\.name))")
            let seats = try await mapView.getSelection()
            NSLog("[SeatLayerDemo] getSelection -> \(seats.map(\.label))")
            render(selection: seats)
        } catch let error as SeatLayerError {
            NSLog("[SeatLayerDemo] load failed: \(error.errorDescription ?? "?")")
            log(error.requiresAppUpdate ? "please update the app" : "failed: \(error.code)")
        } catch {
            NSLog("[SeatLayerDemo] load failed: \(error)")
            log("failed")
        }
    }

    // MARK: - Actions

    @objc private func holdTapped() {
        Task {
            do {
                let hold = try await mapView.hold()
                NSLog("[SeatLayerDemo] hold -> \(hold?.holdId ?? "nil") items=\(hold?.items?.count ?? 0)")
                log(hold.map { "held \($0.holdId) · \($0.items?.count ?? 0) seats" } ?? "no hold")
            } catch let error as SeatLayerError {
                NSLog("[SeatLayerDemo] hold failed: \(error.code)")
                log("hold failed: \(error.code)")
            } catch { log("hold failed") }
        }
    }

    @objc private func bestAvailableTapped() {
        Task {
            do {
                let result = try await mapView.bestAvailable(qty: 4)
                NSLog("[SeatLayerDemo] bestAvailable -> \(result?.labels ?? [])")
                log("best available: \((result?.labels ?? []).joined(separator: ", "))")
            } catch let error as SeatLayerError {
                // `not_enough_together` and `sold_out` arrive here with their
                // API code intact.
                NSLog("[SeatLayerDemo] bestAvailable failed: \(error.code)")
                log("best available: \(error.code)")
            } catch { log("best available failed") }
        }
    }

    @objc private func zoomTapped() {
        Task {
            try? await mapView.zoomToFit()
            NSLog("[SeatLayerDemo] zoomToFit -> ok")
            log("zoomed to fit")
        }
    }

    // MARK: - UI

    private func log(_ text: String) {
        statusLabel.text = text
    }

    private func render(selection seats: [SelectedSeat]) {
        guard !seats.isEmpty else {
            selectionLabel.text = "No seats selected"
            return
        }
        let labels = seats.map(\.buyerFacingLabel).joined(separator: ", ")
        let total = seats.compactMap(\.price).reduce(0, +)
        selectionLabel.text = "\(seats.count) selected · \(labels)\nTotal $\(Int(total))"
    }

    private func showModeBadge(_ mode: EventMode) {
        switch mode {
        case .test:
            modeBadge.text = "  TEST EVENT · BOOKS NOTHING  "
            modeBadge.backgroundColor = UIColor(red: 0.85, green: 0.55, blue: 0.1, alpha: 1)
            modeBadge.isHidden = false
        case .live:
            modeBadge.isHidden = true
        case .unknown(let raw):
            modeBadge.text = "  MODE: \(raw.uppercased())  "
            modeBadge.backgroundColor = .darkGray
            modeBadge.isHidden = false
        }
    }

    private func buildUI() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)
        view.addSubview(mapView)

        modeBadge.font = .systemFont(ofSize: 11, weight: .bold)
        modeBadge.textColor = .black
        modeBadge.layer.cornerRadius = 4
        modeBadge.clipsToBounds = true
        modeBadge.isHidden = true
        modeBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeBadge)

        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = UIColor(white: 0.65, alpha: 1)
        statusLabel.numberOfLines = 2
        statusLabel.text = "starting…"

        selectionLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        selectionLabel.textColor = .white
        selectionLabel.numberOfLines = 3
        selectionLabel.text = "No seats selected"

        for (button, title, action) in [
            (holdButton, "Hold", #selector(holdTapped)),
            (bestAvailableButton, "Best 4", #selector(bestAvailableTapped)),
            (zoomButton, "Fit", #selector(zoomTapped)),
        ] {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            button.setTitleColor(.black, for: .normal)
            button.backgroundColor = UIColor(red: 0.34, green: 0.85, blue: 0.64, alpha: 1)
            button.layer.cornerRadius = 8
            button.addTarget(self, action: action, for: .touchUpInside)
        }

        let buttons = UIStackView(arrangedSubviews: [holdButton, bestAvailableButton, zoomButton])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually

        let panel = UIStackView(arrangedSubviews: [selectionLabel, statusLabel, buttons])
        panel.axis = .vertical
        panel.spacing = 10
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: guide.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // A DEFINITE height. The map never lives in a scroll view.
            mapView.bottomAnchor.constraint(equalTo: panel.topAnchor, constant: -12),

            modeBadge.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            modeBadge.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            modeBadge.heightAnchor.constraint(equalToConstant: 20),

            panel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            panel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            panel.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            buttons.heightAnchor.constraint(equalToConstant: 42),
        ])
    }
}

// MARK: - SeatLayerViewDelegate

extension DemoViewController: SeatLayerViewDelegate {
    func seatLayerViewDidBecomeReady(_ view: SeatLayerView, info: ReadyInfo) {
        NSLog("[SeatLayerDemo] delegate ready mode=\(info.mode.rawValue)")
    }

    func seatLayerView(_ view: SeatLayerView, selectionDidChange seats: [SelectedSeat]) {
        NSLog("[SeatLayerDemo] selection.changed -> \(seats.map(\.label))")
        render(selection: seats)
    }

    func seatLayerView(_ view: SeatLayerView, holdDidChange hold: HoldResult) {
        NSLog("[SeatLayerDemo] hold.changed -> \(hold.holdId) expires in \(Int(hold.timeRemaining))s")
    }

    func seatLayerViewHoldDidExpire(_ view: SeatLayerView) {
        NSLog("[SeatLayerDemo] hold.expired")
        log("hold expired")
    }

    func seatLayerView(_ view: SeatLayerView, didFailWith error: SeatLayerError) {
        NSLog("[SeatLayerDemo] error -> \(error.code): \(error.errorDescription ?? "")")
    }

    func seatLayerView(_ view: SeatLayerView, didReceiveHint message: String?) {
        NSLog("[SeatLayerDemo] hint -> \(message ?? "nil")")
    }

    func seatLayerView(_ view: SeatLayerView, didReceiveUnknownEvent name: String, payload: JSONValue?) {
        NSLog("[SeatLayerDemo] unknown event `\(name)` — bundle is ahead of this build")
    }
}
