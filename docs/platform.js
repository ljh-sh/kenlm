// Detect the user's platform and highlight the matching download.
(function () {
    var ua = navigator.userAgent || "";

    var isMac = /Macintosh|Mac OS X|Mac OS X.*Firefox/.test(ua);
    var isWin = /Windows|Win64|Win32/.test(ua);
    var isLinux = /Linux|X11/.test(ua) && !isAndroid;
    var isArm = /arm64|aarch64|ARM/.test(ua);

    // Pick the best target.
    var pick;
    if (isMac) {
        pick = "aarch64-macos";
    } else if (isWin) {
        pick = isArm ? "aarch64-windows" : "x86_64-windows";
    } else if (isLinux) {
        pick = isArm ? "aarch64-linux-musl" : "x86_64-linux-musl";
    } else {
        pick = "x86_64-linux-musl"; // safe default
    }

    // Highlight the card.
    var cards = document.querySelectorAll(".platform[data-target]");
    for (var i = 0; i < cards.length; i++) {
        if (cards[i].getAttribute("data-target") === pick) {
            cards[i].classList.add("highlight");
        }
    }

    // Rewrite the detect-line to a useful message.
    var msg = {
        "x86_64-linux-musl": "Detected Linux x86_64 → highlighted above. (Alpine works too — the same archive is musl-static.)",
        "aarch64-linux-musl": "Detected Linux aarch64 → highlighted above.",
        "x86_64-linux-gnu": "Detected a glibc x86_64 system → highlighted above.",
        "aarch64-linux-gnu": "Detected a glibc aarch64 system → highlighted above.",
        "aarch64-macos": "Detected macOS Apple Silicon → highlighted above.",
        "x86_64-windows": "Detected Windows x64 → highlighted above.",
        "aarch64-windows": "Detected Windows ARM64 → highlighted above."
    };
    var el = document.getElementById("detect-line");
    if (el) el.textContent = msg[pick] || ("Detected target: " + pick);

    // Update the primary CTA to point at the chosen download.
    var cta = document.getElementById("cta-main");
    if (cta) {
        cta.href = "https://github.com/ljh-sh/kenlm/releases/download/v0.1.0/kenlm-" + pick + (pick.indexOf("windows") >= 0 ? ".zip" : ".tar.gz");
    }
})();
