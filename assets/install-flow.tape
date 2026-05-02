# VHS tape: install + integrity verification flow
# Generates: assets/install-flow.gif

Output assets/install-flow.gif
Set Theme "Catppuccin Mocha"
Set FontSize 16
Set Width 1100
Set Height 720
Set Padding 24
Set TypingSpeed 30ms
Set PlaybackSpeed 1.0

Hide
Type "cd /tmp/bolts-vhs-demo" Enter
Sleep 200ms
Show

Type "# Step 1 — clone the package next to your target project" Sleep 600ms Enter
Type "git clone --branch v1.4.0 https://github.com/lhyman1701/bolts-package.git pkg" Sleep 300ms Enter
Sleep 1500ms

Type "# Step 2 — run the installer at your target project's repo root" Sleep 600ms Enter
Type "./pkg/install.sh ./target-repo" Sleep 300ms Enter
Sleep 4500ms

Type "# Step 3 — verify integrity at destination" Sleep 600ms Enter
Type "cd target-repo/.claude/plans && shasum -a 256 -c MANIFEST.sha256" Sleep 300ms Enter
Sleep 2500ms

Type "# Step 4 — open Claude Code and paste the kickoff prompt" Sleep 600ms Enter
Type "# (kickoff prompt is in 2026-05-02-make-bolt-KICKOFF-PROMPT.md)" Sleep 800ms Enter
Sleep 3000ms
