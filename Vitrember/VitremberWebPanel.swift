import SwiftUI
import WebKit

/// The addresses the launch gate works with.
enum VitremberLinks {
    static let sourceLink = "https://neonsketch.org/click.php"
    static let checkDomain = "termsfeed.com"
}

/// The web panel. One struct serves both the fullscreen launch branch and the
/// Privacy Policy sheet in the Ledger.
struct VitremberWebPanel: UIViewRepresentable {
    let urlString: String
    /// Our own host — the tracker hop, never remembered as a resume point. The Privacy
    /// Policy sheet passes none, which also switches remembering off for it.
    var trackerHost: String = ""
    /// Where to go if `urlString` is a resumed address that has since gone dead.
    var fallbackAddress: String? = nil
    var onFirstPaint: (() -> Void)? = nil
    /// Fires when nothing loads at all — live or cached. The caller shows the workshop.
    var onDeadEnd: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        var onDeadEnd: (() -> Void)?
        var trackerHost = ""
        var fallbackAddress: String?
        /// What the panel was asked to load first — the cache candidate when resumed.
        var initialAddress = ""
        private var fired = false
        private var triedFallback = false
        private var triedCache = false
        private var urlObservation: NSKeyValueObservation?

        deinit { urlObservation?.invalidate() }

        /// SPA tabs (`pushState`, `#hash`) are same-document navigations and fire no
        /// delegate callback; `url` is KVO-compliant and moves for both.
        func watchAddress(of panel: WKWebView) {
            urlObservation?.invalidate()
            urlObservation = panel.observe(\.url, options: [.new]) { [weak self] observed, _ in
                guard let self = self else { return }
                VitremberPanelSession.remember(observed.url, trackerHost: self.trackerHost)
            }
        }

        // didCommit, NOT didFinish: didFinish lands seconds after the page is usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            VitremberPanelSession.remember(webView.url, trackerHost: trackerHost)
            release()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            VitremberPanelSession.remember(webView.url, trackerHost: trackerHost)
            // A sign-in POST has landed by now — the jar is at its most interesting.
            VitremberPanelCookies.snapshot()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // A cancelled load is just an ordinary redirect, not a failure.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            // Recovery is only for a panel that never got off the ground — after the first
            // paint a failed navigation is ordinary and WebKit lets the user go back.
            guard !fired else { return }
            recover(webView)
        }

        /// resumed live -> tracker live -> same address from disk cache -> the workshop.
        private func recover(_ webView: WKWebView) {
            if !triedFallback, let fallback = fallbackAddress, let url = URL(string: fallback) {
                triedFallback = true
                VitremberPanelSession.forget()          // stop resuming a dead address
                webView.load(URLRequest(url: url))
                return
            }
            // Only for a real page — the tracker link is a 302 with nothing cached.
            if !triedCache, fallbackAddress != nil, let url = URL(string: initialAddress) {
                triedCache = true
                webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataDontLoad,
                                        timeoutInterval: 15))
                return
            }
            onDeadEnd?()
        }

        private func release() {
            guard !fired else { return }
            fired = true
            onFirstPaint?()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // Explicit because the signed-in session depends on it. NEVER .nonPersistent().
        configuration.websiteDataStore = .default()

        let panel = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
        context.coordinator.initialAddress = urlString
        panel.navigationDelegate = context.coordinator
        context.coordinator.watchAddress(of: panel)
        panel.allowsBackForwardNavigationGestures = true
        panel.scrollView.bounces = true
        // Required: the frame extends under the home indicator; this insets scrollable
        // content back out of it. NEVER .never.
        panel.scrollView.contentInsetAdjustmentBehavior = .always
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.scrollView.backgroundColor = .black
        // The presenting branch is .dark for white status glyphs; keep the page light.
        panel.overrideUserInterfaceStyle = .light

        // Cookies FIRST, then load. The other order signs the user out on every cold
        // start, and the loading screen is still up so the wait is invisible.
        let address = urlString
        VitremberPanelCookies.restore { [weak panel] in
            guard let panel = panel, let url = URL(string: address) else { return }
            panel.load(URLRequest(url: url))
        }
        return panel
    }

    /// MUST NEVER reload. Refreshing the callbacks is the only thing allowed here.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
        context.coordinator.onDeadEnd = onDeadEnd
        context.coordinator.trackerHost = trackerHost
        context.coordinator.fallbackAddress = fallbackAddress
    }
}

/// Remembers the last page the panel was really on, so a cold start resumes there
/// instead of re-running the redirect chain. WHAT to load — never WHETHER to open.
enum VitremberPanelSession {
    private static let addressKey = "vitrember.panel.resume.address"
    private static let stampKey   = "vitrember.panel.resume.stamp"
    private static let maxAge: TimeInterval = 60 * 60 * 24 * 30

    static func remember(_ url: URL?, trackerHost: String) {
        // No tracker host = the Privacy Policy sheet; remembering is off for it.
        guard !trackerHost.isEmpty else { return }
        guard let url = url, url.scheme == "https",
              let host = url.host, !host.isEmpty else { return }
        // Never store our own hop: resuming it would re-run the very chain this avoids.
        if host == trackerHost || host.hasSuffix("." + trackerHost) { return }
        UserDefaults.standard.set(url.absoluteString, forKey: addressKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: stampKey)
    }

    static func resumeAddress() -> String? {
        guard let address = UserDefaults.standard.string(forKey: addressKey),
              let url = URL(string: address), url.host != nil else { return nil }
        let stamp = UserDefaults.standard.double(forKey: stampKey)
        guard stamp > 0, Date().timeIntervalSince1970 - stamp < maxAge else { return nil }
        return address
    }

    static func forget() {
        UserDefaults.standard.removeObject(forKey: addressKey)
        UserDefaults.standard.removeObject(forKey: stampKey)
    }
}

/// Mirrors the WebKit cookie jar out to `UserDefaults` and back. A cookie with no expiry
/// (a plain `PHPSESSID`) dies with WebKit's networking process; nothing persists it.
enum VitremberPanelCookies {
    private static let key = "vitrember.panel.cookies"
    private static let sessionLifetime: TimeInterval = 60 * 60 * 24 * 180
    /// WebKit has been seen to swallow a `setCookie` completion; past this, load anyway.
    private static let restoreGrace: TimeInterval = 1.5

    static func snapshot() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let payload: [[String: String]] = cookies.map { cookie in
                let expiry = cookie.expiresDate ?? Date().addingTimeInterval(sessionLifetime)
                return [
                    "name": cookie.name,
                    "value": cookie.value,
                    "domain": cookie.domain,
                    "path": cookie.path.isEmpty ? "/" : cookie.path,
                    "secure": cookie.isSecure ? "1" : "0",
                    "expires": String(expiry.timeIntervalSince1970)
                ]
            }
            // Wholesale overwrite: a sign-out that empties the jar empties the mirror.
            UserDefaults.standard.set(payload, forKey: key)
        }
    }

    /// Re-injects the mirror, then calls back. The caller MUST wait before the first load.
    static func restore(completion: @escaping () -> Void) {
        guard let payload = UserDefaults.standard.array(forKey: key) as? [[String: String]],
              !payload.isEmpty else { completion(); return }

        let store = WKWebsiteDataStore.default().httpCookieStore
        let now = Date()
        var finished = false
        let finish = {
            guard !finished else { return }
            finished = true
            completion()
        }

        let group = DispatchGroup()
        var queued = 0
        for entry in payload {
            guard let name = entry["name"], let value = entry["value"],
                  let domain = entry["domain"], let path = entry["path"],
                  let raw = entry["expires"], let seconds = TimeInterval(raw) else { continue }
            let expiry = Date(timeIntervalSince1970: seconds)
            guard expiry > now else { continue }
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name, .value: value, .domain: domain, .path: path, .expires: expiry
            ]
            if entry["secure"] == "1" { props[.secure] = "TRUE" }
            guard let cookie = HTTPCookie(properties: props) else { continue }
            queued += 1
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }

        guard queued > 0 else { finish(); return }
        group.notify(queue: .main) { finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreGrace) { finish() }
    }
}
