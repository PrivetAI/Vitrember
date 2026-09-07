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
    /// Fires once, the moment the page starts rendering, so the caller can lift the
    /// loading screen. The Privacy Policy use site passes nothing.
    var onFirstPaint: (() -> Void)? = nil

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onFirstPaint: (() -> Void)?
        private var fired = false

        // didCommit, NOT didFinish: on a heavy landing page didFinish arrives seconds
        // after the page is already visible and usable.
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            release()
        }

        // A real failure must also lift the overlay, or the loading screen hangs forever.
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            let ns = error as NSError
            // A cancelled load is just an ordinary redirect, not a failure.
            if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return }
            release()
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

        let panel = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.onFirstPaint = onFirstPaint
        panel.navigationDelegate = context.coordinator
        panel.allowsBackForwardNavigationGestures = true
        panel.scrollView.bounces = true
        // Required, not optional: the frame extends under the home indicator, and this
        // is what insets scrollable content back out of it. NEVER .never.
        panel.scrollView.contentInsetAdjustmentBehavior = .always
        // Opaque with a solid colour so the safe-area band never flashes white.
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.scrollView.backgroundColor = .black
        // The branch presenting this runs in the dark scheme so the status bar glyphs
        // turn white. Pin the page itself back to light so that trait never reaches the
        // site as prefers-color-scheme: dark.
        panel.overrideUserInterfaceStyle = .light

        if let url = URL(string: urlString) {
            panel.load(URLRequest(url: url))
        }
        return panel
    }

    /// MUST NEVER reload. Reloading here restarts the page on every SwiftUI re-render.
    /// Refreshing the callback is the only thing allowed.
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onFirstPaint = onFirstPaint
    }
}
