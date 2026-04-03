# whiptail-replay

A drop-in replacement for [`whiptail`](https://linux.die.net/man/1/whiptail) that can **record** interactive answers and **replay** them non-interactively.

Use it to automate scripts that drive dialog-based configuration (e.g. Debian `dpkg-reconfigure`, custom installers, etc.) without modifying those scripts.

---

## How it works

`whiptail-replay` intercepts every `whiptail` invocation and looks up the command-line arguments in a JSON configuration file.

- **Replay mode** (default): reads pre-recorded answers from the config file and exits with the stored stderr/exit-code — no terminal interaction required.
- **Record mode**: calls the real `whiptail`, captures its output, appends a new entry to the config file, then returns the captured output to the caller.

---

## Installation

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/StevenVanAcker/whiptail-replay/master/install.sh)"
```

This downloads `whiptail-replay` from GitHub and installs it to `/usr/local/bin/whiptail`, which shadows `/usr/bin/whiptail` on most Linux distributions (because `/usr/local/bin` comes first in `PATH`).

To install to a custom location:

```bash
sudo INSTALL_DIR=/opt/bin bash -c "$(curl -fsSL https://raw.githubusercontent.com/StevenVanAcker/whiptail-replay/master/install.sh)"
```

---

## Configuration file format

The config file is a JSON array. Each element maps a set of `whiptail` arguments to the expected outcome:

```json
[
  {
    "args": ["--yesno", "Continue with installation?", "8", "40"],
    "stderr": "",
    "exitcode": 0
  },
  {
    "args": ["--inputbox", "Enter your name:", "8", "40"],
    "stderr": "Alice",
    "exitcode": 0
  },
  {
    "args": ["--menu", "Choose an option:", "15", "60", "4",
             "1", "First", "2", "Second"],
    "stderr": "1",
    "exitcode": 0
  }
]
```

**Fields:**

| Field | Description |
|-------|-------------|
| `args` | Argument list passed to `whiptail` (excluding `argv[0]`). Supports fnmatch wildcards (`*`, `?`, `[...]`) per element. |
| `stderr` | String written to stderr when replaying (whiptail writes selections here) |
| `exitcode` | Process exit code (0 = OK/Yes, 1 = Cancel/No) |

---

## Matching

By default, matching is **exact**: every element of the stored `args` must equal the corresponding element of the incoming invocation.

### Wildcards

Any element in a stored `args` list may contain [fnmatch](https://docs.python.org/3/library/fnmatch.html)-style wildcards. This lets one entry cover multiple related invocations:

```json
{
  "args": ["--yesno", "Install *?", "8", "40"],
  "stderr": "",
  "exitcode": 0
}
```

This matches `--yesno "Install package-foo?" 8 40`, `--yesno "Install package-bar?" 8 40`, etc.

### Normalization (`WHIPTAILNORMALIZE`)

When `WHIPTAILNORMALIZE` is set, the following cosmetic arguments are stripped from both stored and incoming args before matching:

- `--backtitle <value>` — varies across invocations but does not affect dialog semantics
- `--fb` — force-black-background flag, purely visual
- Height and width positional arguments (the two numbers after the dialog text)

This lets you record with one geometry and replay with another, or ignore the application title:

```bash
# Recorded as: --yesno "Continue?" 8 40
# Still matches when called as:
export WHIPTAILNORMALIZE=1
whiptail --backtitle "My App v2.1" --yesno "Continue?" 12 60
```

---

## Sequence mode (`WHIPTAILSEQUENCE`)

By default entries are matched by argument list. If the same dialog appears multiple times and should return different answers each time, set `WHIPTAILSEQUENCE=1` to consume entries in order instead:

```bash
export WHIPTAILSEQUENCE=1
export WHIPTAILREPLAYFILE=answers.json
your-script.sh
```

The current position is tracked in `<WHIPTAILREPLAYFILE>.seq`. Delete or reset this file to replay from the beginning.

---

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WHIPTAILREPLAYFILE` | — | Path to the JSON config file (required) |
| `WHIPTAILRECORD` | unset | Set to any value to enable record mode |
| `WHIPTAILPATH` | `/usr/bin/whiptail` | Path to the real `whiptail` binary (record mode and passthrough) |
| `WHIPTAILNORMALIZE` | unset | Strip cosmetic args (backtitle, fb, geometry) before matching |
| `WHIPTAILSEQUENCE` | unset | Replay entries in order rather than by argument match |
| `WHIPTAILREPLAYMISSING` | — | Set to `passthrough` to call real whiptail when no entry matches |
| `WHIPTAILDEBUG` | unset | Write match/miss debug info to stderr |

---

## Subcommands

### `whiptail --list`

Print all recorded entries in a table:

```bash
WHIPTAILREPLAYFILE=answers.json whiptail --list
```

---

## Usage examples

### Replay mode

```bash
export WHIPTAILREPLAYFILE=/etc/myapp/answers.json
./my-installer-script.sh   # whiptail calls are answered automatically
```

### Record mode (create the config file)

```bash
export WHIPTAILREPLAYFILE=/etc/myapp/answers.json
export WHIPTAILRECORD=1
export WHIPTAILPATH=/usr/bin/whiptail

./my-installer-script.sh   # interact normally; answers are recorded
```

Run the script interactively once in record mode, then replay it as many times as needed.

### Partial automation (`WHIPTAILREPLAYMISSING=passthrough`)

When automating only some dialogs and leaving others interactive:

```bash
export WHIPTAILREPLAYFILE=/etc/myapp/partial.json
export WHIPTAILREPLAYMISSING=passthrough
export WHIPTAILPATH=/usr/bin/whiptail
./my-installer-script.sh
```

---

## Notes

- whiptail draws its dialog to `/dev/tty` and writes the user's selection to **stderr**. `whiptail-replay` faithfully reproduces this: selections are replayed on stderr.
- If the same argument list is recorded twice, the existing entry is updated in place.
- Config writes are atomic (`os.replace`) and protected by an exclusive file lock, so concurrent invocations are safe.
- The config file is human-readable and can be edited by hand.

---

## Credits

All code in this repository was written by [Claude Code](https://claude.ai/code).
