import SwiftUI

@main
struct VitremberApp: App {
    @StateObject private var gate = VitremberLaunchGate(sourceLink: VitremberLinks.sourceLink,
                                                   checkDomain: VitremberLinks.checkDomain)
    @StateObject private var store = VitremberStore()
    @State private var vitremberPagePainted = false
    @State private var vitremberPanelDeadEnd = false   // panel loaded nothing; verdict untouched
    @Environment(\.scenePhase) private var scenePhase

    /// Decides WHAT the panel loads after a `true` verdict, never whether it opens.
    /// Computed, not a `let` in the ViewBuilder (iOS 15 result builders reject it).
    private var resumeAddress: String? { VitremberPanelSession.resumeAddress() }
    private var trackerHost: String { URL(string: gate.sourceLink)?.host ?? "" }

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = gate.ready {
                    if ready && !vitremberPanelDeadEnd {
                        // Web panel. The frame RESPECTS the top safe area, so page
                        // content can never render under the notch, and the opaque black
                        // band above it is drawn in the dark scheme so the clock, Wi-Fi
                        // and battery stay white and readable.
                        ZStack {
                            VitremberWebPanel(urlString: resumeAddress ?? gate.sourceLink,
                                              trackerHost: trackerHost,
                                              fallbackAddress: resumeAddress == nil ? nil : gate.sourceLink,
                                              onFirstPaint: { withAnimation { vitremberPagePainted = true } },
                                              onDeadEnd: { vitremberPanelDeadEnd = true })
                                .edgesIgnoringSafeArea(.bottom)
                                .background(Color.black.ignoresSafeArea())
                            if !vitremberPagePainted {
                                VitremberLoadingScreen()
                                    .transition(.opacity)
                                    .onAppear {
                                        // Hang guard, not a deadline. Long on purpose:
                                        // firing early just reveals the black page this
                                        // exists to hide.
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                            vitremberPagePainted = true
                                        }
                                    }
                            }
                        }
                        .preferredColorScheme(.dark)
                    } else {
                        // The workshop. Its colour scheme is declared HERE, per branch —
                        // a single modifier on the enclosing Group would override the
                        // .dark above and make the status bar glyphs vanish.
                        RootShell(store: store)
                            .preferredColorScheme(.dark)
                            .onAppear { store.start() }
                    }
                } else {
                    VitremberLoadingScreen()
                        .preferredColorScheme(.dark)
                        .onAppear {
                            gate.start()
                            // The workshop simulates from the moment the app opens, so a
                            // slow check never costs the player their offline credit.
                            store.start()
                        }
                }
            }
            // A deferred verdict can flip native -> panel a few seconds in. Crossfade it;
            // a hard cut reads as a glitch.
            .animation(.easeInOut(duration: 0.25), value: gate.ready)
            .onChange(of: scenePhase) { phase in
                // Last reliable moment before the process can be killed from the switcher.
                // `.inactive` also fires on the way IN; a snapshot is a read, twice is free.
                if gate.ready == true, phase != .active {
                    VitremberPanelCookies.snapshot()
                }
                switch phase {
                case .background:
                    // ONLY here. `.inactive` fires on the way into the background AND on
                    // the way back out, so stamping the clock there would zero every
                    // offline credit the moment the player returned.
                    store.enterBackground()
                case .active:
                    store.returnToForeground()
                default:
                    // `.inactive` — a control centre pull, a call banner. Stop the
                    // treadle so it cannot be left held down, and change nothing else.
                    store.endPump()
                }
            }
        }
    }
}

/// The launch gate.
///
/// It resolves as early as the redirect chain allows, retries once on a transport error,
/// gives up on a STALL rather than on a fixed deadline, and — when it still cannot decide
/// — hands over the workshop immediately while it keeps looking in the background.
@MainActor
final class VitremberLaunchGate: ObservableObject {
    /// nil = still deciding (loading screen) · false = the workshop · true = the web panel
    @Published private(set) var ready: Bool? = nil

    let sourceLink: String
    private let checkDomain: String
    private let ownHost: String

    /// Stall limit while the LOADING SCREEN is up. Deliberately short: a late verdict can
    /// still swap the panel in, so there is nothing to gain by making anyone wait here.
    private let foregroundStall: TimeInterval = 3
    /// Stall limit once the workshop is already on screen. Nobody is waiting, so the
    /// background attempts can afford to be patient.
    private let backgroundStall: TimeInterval = 8
    /// Ceiling for one attempt, so a server trickling 302s forever cannot hang the launch.
    private let attemptCeiling: TimeInterval = 30
    /// How long after launch a late verdict may still replace the workshop with the panel.
    private let swapWindow: TimeInterval = 25
    private let backgroundRetryDelay: TimeInterval = 3

    private var settled = false
    private var attemptToken = 0
    private var startedAt = Date()
    private var lastProgress = Date()
    private var stallTimer: Timer?
    private var task: URLSessionTask?
    private var session: URLSession?

    init(sourceLink: String, checkDomain: String) {
        self.sourceLink = sourceLink
        self.checkDomain = checkDomain
        self.ownHost = URL(string: sourceLink)?.host ?? ""
    }

    func start() {
        guard attemptToken == 0 else { return }   // .onAppear can fire more than once
        startedAt = Date()
        attempt(1)
    }

    private func attempt(_ number: Int) {
        guard !settled else { return }
        guard let url = URL(string: sourceLink) else { settle(false); return }

        attemptToken += 1
        let token = attemptToken

        var request = URLRequest(url: url)
        // HEAD, never GET. A default GET downloads the whole landing page, throws the
        // body away, and the WebView then fetches the same page again from scratch.
        request.httpMethod = "HEAD"
        // The one request whose entire value is being LIVE: a 301/308 is cacheable with
        // no headers at all, and a cached hop answers from a snapshot, not the Worker.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        let configuration = URLSessionConfiguration.default
        // Only once the workshop is on screen may an attempt sit and wait for the radio.
        // While the loading screen is up, a dead network must fail instantly.
        configuration.waitsForConnectivity = (ready != nil)
        configuration.timeoutIntervalForResource = attemptCeiling
        configuration.urlCache = nil
        // The gate is a routing probe, not a visit. URLSession's jar is NOT the WebView's,
        // so a tracker cookie stored here is a second click identity nothing reads back.
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false

        let watcher = VitremberPathWatcher(checkDomain: checkDomain, ownHost: ownHost)
        watcher.onProgress = { [weak self] in
            Task { @MainActor in self?.lastProgress = Date() }
        }
        watcher.onEarlyVerdict = { [weak self] verdict in
            Task { @MainActor in self?.settle(verdict) }
        }

        let session = URLSession(configuration: configuration, delegate: watcher, delegateQueue: nil)
        lastProgress = Date()
        armStallWatchdog(attempt: number, token: token)

        self.session = session
        task = session.dataTask(with: request) { [weak self] _, response, error in
            // A delegate session retains its delegate until invalidated; without this one
            // watcher per attempt survives for the whole process lifetime.
            session.finishTasksAndInvalidate()
            Task { @MainActor in
                guard let self = self, !self.settled, self.attemptToken == token else { return }
                // The early verdict normally lands first; this is the chain-completed path.
                if watcher.sawCheckDomain { self.settle(false); return }
                if let final = watcher.resolvedURL?.absoluteString,
                   final.contains(self.checkDomain) { self.settle(false); return }
                if let http = response as? HTTPURLResponse,
                   let address = http.url?.absoluteString,
                   address.contains(self.checkDomain) { self.settle(false); return }
                if error != nil { self.failed(attempt: number, token: token); return }
                self.settle(true)
            }
        }
        task?.resume()
    }

    /// Progress-aware watchdog. It never kills a chain that is still moving.
    private func armStallWatchdog(attempt number: Int, token: Int) {
        stallTimer?.invalidate()
        stallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, !self.settled, self.attemptToken == token else {
                    timer.invalidate(); return
                }
                let limit = self.ready == nil ? self.foregroundStall : self.backgroundStall
                let stalled = Date().timeIntervalSince(self.lastProgress) > limit
                let overCeiling = Date().timeIntervalSince(self.startedAt) > self.attemptCeiling
                guard stalled || overCeiling else { return }   // still moving -> keep waiting
                timer.invalidate()
                self.session?.invalidateAndCancel()   // cancels the task AND frees the delegate
                self.failed(attempt: number, token: token)
            }
        }
    }

    private func failed(attempt number: Int, token: Int) {
        // The cancelled task's completion handler and the watchdog both land here. The
        // token makes whichever arrives second a no-op.
        guard !settled, attemptToken == token else { return }
        attemptToken += 1
        stallTimer?.invalidate()

        // One immediate retry. Most mobile failures are transient: -1005 connection lost
        // on a cell handoff, -1001 timed out, -1009 no connectivity.
        if number == 1 { attempt(2); return }

        // Out of fast options. Hand over the workshop NOW rather than holding anyone on
        // a loading screen, and keep looking in the background.
        if ready == nil { ready = false }
        scheduleBackgroundAttempt(next: number + 1)
    }

    private func scheduleBackgroundAttempt(next number: Int) {
        guard !settled, Date().timeIntervalSince(startedAt) < swapWindow else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundRetryDelay) { [weak self] in
            Task { @MainActor in
                guard let self = self, !self.settled,
                      Date().timeIntervalSince(self.startedAt) < self.swapWindow else { return }
                self.attempt(number)
            }
        }
    }

    private func settle(_ verdict: Bool) {
        guard !settled else { return }
        // A verdict arriving after the swap window may still close the gate — the
        // workshop is where we already are — but must never yank someone who has been
        // playing for half a minute into a web panel.
        if verdict, ready == false, Date().timeIntervalSince(startedAt) > swapWindow {
            settled = true
            stallTimer?.invalidate()
            return
        }
        settled = true
        stallTimer?.invalidate()
        ready = verdict
    }
}

/// Follows the redirect chain and decides at the FIRST hop that carries information,
/// instead of waiting for the whole chain to resolve.
final class VitremberPathWatcher: NSObject, URLSessionTaskDelegate {
    /// Fires on every observed hop — re-arms the stall watchdog.
    var onProgress: (() -> Void)?
    /// Fires at most once, the moment the chain becomes decidable.
    var onEarlyVerdict: ((Bool) -> Void)?

    private(set) var resolvedURL: URL?
    private(set) var sawCheckDomain = false

    private let checkDomain: String
    private let ownHost: String
    private var decided = false

    init(checkDomain: String, ownHost: String) {
        self.checkDomain = checkDomain
        self.ownHost = ownHost
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        resolvedURL = request.url
        onProgress?()

        if let address = request.url?.absoluteString {
            if address.contains(checkDomain) {
                // Definitive: the review branch. Nothing later can change this.
                sawCheckDomain = true
                decide(false)
            } else if let host = request.url?.host, !hostIsOurs(host) {
                // The first hop that LEAVES our own domain without being the check
                // domain is the whole verdict. Everything after it cannot change it.
                decide(true)
            }
            // A hop that stays on our own host decides nothing.
        }
        completionHandler(request)   // NEVER stop the chain
    }

    private func hostIsOurs(_ host: String) -> Bool {
        !ownHost.isEmpty && (host == ownHost || host.hasSuffix("." + ownHost))
    }

    private func decide(_ verdict: Bool) {
        guard !decided else { return }
        decided = true
        onEarlyVerdict?(verdict)
    }
}
