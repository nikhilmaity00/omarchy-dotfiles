# Omarchy Agent Multi-Usage Plugin (`custom.agent-usage`)

An enhanced Omarchy top-bar plugin that displays **every active AI agent in use** with its individual icon and utilized rate-limit percentage side-by-side in your top bar.

---

## 🌟 Features

- **Multi-Agent Top Bar Icons**: Shows individual SVG logos (or optical glyph fallbacks) for every active agent (`Gemini`, `Codex`, `Claude`, `Fireworks`, etc.).
- **Live Utilization Percentages**: Displays the rate limit window percentage (e.g. `45%`, `88%`, `12%`) or prepaid credit balance next to each icon.
- **Filters Active Agents Only**: Automatically hides agents with no current activity or rate limit data so your top bar stays clean.
- **Dynamic Color Warnings**:
  - 🟢 **Normal**: Theme foreground
  - 🟡 **Warning (≥80% used)**: Soft warning yellow accent
  - 🔴 **Urgent (≥90% used)**: Highlighting alert red
- **Interactive Dashboard Integration**:
  - **Left-Click** any agent's icon in the top bar to open the Omarchy Agents Dashboard focused directly on that agent's tab.
  - **Middle-Click** to cycle through active agent subscriptions.
  - **Right-Click** to launch the interactive agent picker CLI (`omarchy-agent --pick`).
  - **Hover Tooltip** shows full status (limit window, reset countdown, and today's token count).

---

## 📦 Installation

Run the bundled installation script from this directory:

```bash
./install.sh
```

Or manually symlink into your Omarchy plugins folder:

```bash
mkdir -p ~/.config/omarchy/plugins
ln -sf "$(pwd)" ~/.config/omarchy/plugins/custom.agent-usage
omarchy plugin enable custom.agent-usage
```

---

## ⚙️ Configuration

You can customize the bar behavior via Omarchy CLI or in `~/.config/omarchy/shell.json`:

| Option | Default | Description |
|---|---|---|
| `barMode` | `"multi"` | `"multi"` shows every active agent icon & percentage; `"single"` falls back to one unified icon. |
| `showPercentage` | `true` | Show or hide the numerical percentage label next to agent icons. |
| `refreshIntervalSec` | `900` | Collector refresh interval in seconds (default 15 minutes). |

### Example CLI commands:

```bash
# Toggle to single icon mode
omarchy bar set custom.agent-usage barMode "single"

# Toggle back to multi-icon mode
omarchy bar set custom.agent-usage barMode "multi"

# Hide percentages (icons only)
omarchy bar set custom.agent-usage showPercentage false --json
```

---

## 🧩 Compatibility

Works seamlessly with existing Omarchy agent collectors (`omarchy-agent-usage-update`, `chispes.agent-gemini`, Codex CLI, Claude Code, Fireworks, etc.) by reading from `~/.local/state/omarchy/agents/usage/`.
