# CLAUDE.md — whiptail-replay

## Project overview

`whiptail-replay` is a single-file Python script that acts as a drop-in replacement for the `whiptail` terminal dialog utility. It enables non-interactive automation of scripts that call `whiptail` by recording and replaying question/answer pairs.

## Repository layout

```
whiptail-replay   — the main Python script (chmod +x)
install.sh        — installer that shadows /usr/bin/whiptail
README.md         — user-facing documentation
CLAUDE.md         — this file
todo.txt          — original task specification
```

## Key design decisions

- **Single-file script, no dependencies** — only the Python 3 standard library is used (`fcntl`, `fnmatch`, `json`, `os`, `subprocess`, `sys`, `tempfile`).
- **Matching is exact by default** — entries are keyed on the full `argv[1:]` list. Different invocations of the same dialog type are distinct entries.
- **Wildcards via fnmatch** — any element of a stored `args` list may contain `*`/`?`/`[...]` wildcards, matched per-element with `fnmatch.fnmatchcase`. The first matching entry wins.
- **Normalization is opt-in** — `WHIPTAILNORMALIZE` strips cosmetic args (`--backtitle`, `--fb`, height, width) from both stored and incoming args before matching. Normalization is applied symmetrically at match time, not at write time, so the raw args are always stored.
- **Sequence mode** — `WHIPTAILSEQUENCE` consumes entries in order. The index is stored atomically in `<REPLAY_FILE>.seq`. Both the seq file and the config file share the same lock, so concurrent invocations are safe.
- **stderr carries selections** — `whiptail` writes the user's choice to stderr, not stdout. `whiptail-replay` preserves this convention both when recording and replaying.
- **Record updates in place** — re-recording an already-known (normalized) argument list overwrites the previous entry rather than appending a duplicate.
- **Atomic config writes** — config is written to a temp file in the same directory, then `os.replace()`-d into place to prevent partial writes.
- **File locking** — an exclusive `fcntl.flock` on a companion `.lock` file serializes concurrent config reads/writes. The lock is released before blocking on user input in record mode.
- **Passthrough on miss** — `WHIPTAILREPLAYMISSING=passthrough` delegates to the real whiptail instead of failing when no entry matches. The lock is released before calling the real binary.
- **Install via PATH shadowing** — `install.sh` downloads `whiptail-replay` from GitHub and places it at `/usr/local/bin/whiptail`, which precedes `/usr/bin` in the default `PATH`. The installer is designed to be run directly via `curl | bash` without cloning the repository.

## Environment variables

| Variable | Purpose |
|----------|---------|
| `WHIPTAILREPLAYFILE` | Path to the JSON config file (required in both modes) |
| `WHIPTAILRECORD` | Presence (any value) enables record mode |
| `WHIPTAILPATH` | Path to the real whiptail binary (default `/usr/bin/whiptail`) |
| `WHIPTAILNORMALIZE` | Strip `--backtitle`, `--fb`, and geometry args before matching |
| `WHIPTAILSEQUENCE` | Consume entries in order; state stored in `<REPLAY_FILE>.seq` |
| `WHIPTAILREPLAYMISSING` | Set to `passthrough` to call real whiptail on no match |
| `WHIPTAILDEBUG` | Emit debug lines to stderr |

## Code structure

| Function | Purpose |
|----------|---------|
| `normalize_args(args)` | Strip cosmetic/geometry args when WHIPTAILNORMALIZE is set |
| `args_match(pattern, actual)` | Per-element fnmatch comparison |
| `find_entry(config, norm_args)` | Linear scan of config, returns first match |
| `load_config(path)` / `save_config(path, config)` | JSON I/O; save is atomic via tempfile + os.replace |
| `_ConfigLock` | Context manager: exclusive flock on `<REPLAY_FILE>.lock` |
| `_read_seq()` / `_write_seq(idx)` | Sequence index I/O (atomic write) |
| `run_real_whiptail(args)` | Invoke real whiptail, capture stderr |
| `cmd_list()` | `--list` subcommand: tabular dump of config |
| `replay(args)` | Replay mode entry point |
| `record(args)` | Record mode entry point |

## Testing

There is no formal test suite. Ad-hoc testing:

```bash
# basic replay
WHIPTAILREPLAYFILE=test.json python3 whiptail-replay --yesno "Test?" 8 40
echo "exit: $?"

# wildcard match
WHIPTAILREPLAYFILE=test.json python3 whiptail-replay --yesno "Install foo?" 8 40

# normalization
WHIPTAILNORMALIZE=1 WHIPTAILREPLAYFILE=test.json \
  python3 whiptail-replay --backtitle "App v2" --yesno "Test?" 12 60

# sequence
WHIPTAILSEQUENCE=1 WHIPTAILREPLAYFILE=test.json python3 whiptail-replay --yesno "?" 8 40

# list
WHIPTAILREPLAYFILE=test.json python3 whiptail-replay --list

# debug
WHIPTAILDEBUG=1 WHIPTAILREPLAYFILE=test.json python3 whiptail-replay --yesno "?" 8 40
```
