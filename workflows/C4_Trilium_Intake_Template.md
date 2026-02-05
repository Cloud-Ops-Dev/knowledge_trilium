# C4 — Structured Intake Template

Adds a consistent intake format for Trilium notes and a helper wrapper on top of C2 threads.

Files:
- workflows/templates/intake.md (template)
- workflows/c4_trilium_intake.sh (helper)
- workflows/state/intake_defaults.json (optional defaults)

Commands:

Start a structured intake thread:
- workflows/c4_trilium_intake.sh start --thread "discord:channel:msg" --title "Intake: Example" --summary "What happened"

Optional fields:
- --source "discord|web|local"
- --context "extra context"
- --signals "risks/signals"
- --actions "next actions"
- --links "reference links"

Append a structured log entry:
- workflows/c4_trilium_intake.sh append --thread "discord:channel:msg" --who "Clay" --text "Additional info"
