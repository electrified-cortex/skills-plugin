# Messaging — Implementation Guide

Technical guidance for building `post` and `drain`. The `spec.md` defines what the tools
must do; this document explains how to do it correctly on supported platforms (PowerShell
and bash).

---

## Atomic Message Write (post)

The spec requires that a partially written file is never visible in the inbox (R12). The
standard technique is **write-to-temp, then rename**:

1. Write the complete message content to a temporary file in a directory outside the
   inbox (e.g., the system temp dir, or a `.tmp/` sibling of `.inbox/`).
2. Rename (move) the temp file into the inbox as the final filename.

The rename is atomic on both POSIX and Windows for same-filesystem operations: the file
appears in the inbox fully formed or not at all. A crash between step 1 and step 2 leaves
an orphaned temp file, not a partial inbox entry.

**PowerShell:**

```powershell
$tmp = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmp -Value $content -Encoding UTF8 -NoNewline
Move-Item -Path $tmp -Destination $inboxPath -Force
```

**bash:**

```bash
tmp=$(mktemp)
printf '%s' "$content" > "$tmp"
mv "$tmp" "$inbox_path"
```

> Do NOT use `Copy-Item` + `Remove-Item` or `cp` + `rm`. Those are two operations, not
> one. Only rename/move is atomic.

---

## Nonce Generation

The spec requires the nonce be from a cryptographically random source (R6). Sequential
counters, PIDs, and `$RANDOM` are all forbidden.

**PowerShell:**

```powershell
$bytes = [byte[]]::new(4)
[System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
$nonce = ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
# yields 8 lowercase hex characters
```

**bash (Linux/macOS):**

```bash
nonce=$(head -c 4 /dev/urandom | xxd -p)
# yields 8 lowercase hex characters
```

Truncate to 6 characters if a shorter nonce is preferred. Either length satisfies R5.

---

## UTC Timestamp

The filename timestamp must be in compact ISO 8601 UTC (`YYYYMMDDTHHmmssZ`).

**PowerShell:**

```powershell
$ts = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
```

**bash:**

```bash
ts=$(date -u '+%Y%m%dT%H%M%SZ')
```

---

## Signal File Write (post)

After the message file is written, `post` must write the signal file. The write is a plain
overwrite — no locking, no read-check-write. Contention between simultaneous posters is
safe: the signal file exists to trigger drain, not to carry information. The content
written (e.g., the timestamp) is irrelevant; only the file modification event matters.

**PowerShell:**

```powershell
Set-Content -Path $signalPath -Value $ts -Encoding UTF8 -Force
```

**bash:**

```bash
printf '%s\n' "$ts" > "$signal_path"
```

If the signal write fails, the tool exits zero. The message is already in the inbox; drain
will pick it up on the next signal or at startup.

---

## Claim Mechanism (drain)

The spec requires an exclusive claim on each message file before reading (R22). The
mechanism is **atomic rename to a `.claimed` extension**:

1. Attempt to rename `<name>.json` to `<name>.json.claimed`.
2. If the rename succeeds, this drain instance owns the file exclusively.
3. If the rename fails (file already gone or renamed by a concurrent drain), skip.

An `os.rename` / `Move-Item` call on an already-absent file will throw. Catch the
exception and treat it as a skipped file — do not re-enumerate or retry.

**PowerShell:**

```powershell
try {
    Move-Item -Path $msgPath -Destination "$msgPath.claimed" -ErrorAction Stop
    # this drain owns the file
} catch {
    continue  # lost the race or file gone; skip
}
```

**bash:**

```bash
if mv "$msg_path" "${msg_path}.claimed" 2>/dev/null; then
    : # this drain owns the file
else
    continue  # lost the race or file gone; skip
fi
```

> POSIX `mv` between paths on the same filesystem is atomic. Windows `MoveFile` (used by
> PowerShell `Move-Item`) is atomic for same-volume moves. Cross-volume moves are NOT
> atomic — never place the inbox on a different volume from `.tmp/`.

---

## Drain-to-Quiescence

An agent that processes messages and then immediately returns to watching the signal file
may miss messages that arrived during processing (the signal fires, the agent is busy, the
signal does not fire again). The solution is to drain again after processing, and repeat
until drain returns empty (R17b).

```text
on_signal():
    loop:
        messages = drain()
        if messages is empty: break
        for msg in messages: process(msg)
    resume watching
```

The extra drain calls are cheap: if the inbox is empty, drain returns immediately.

---

## File Watching (Monitor)

The agent watches `.inbox/<own-name>/.signal` for any change. The implementation of the
watch is platform-defined, but the behaviour must be edge-triggered on file modification.

**Options by platform:**

| Platform | Mechanism |
| --- | --- |
| PowerShell / Windows | `System.IO.FileSystemWatcher` on the signal file |
| bash / Linux | `inotifywait -e close_write .signal` |
| bash / macOS | `fswatch -1 .signal` |
| VS Code agent | VS Code file watcher API |
| Polling fallback | `stat` the signal file mtime every N seconds |

Watch the **signal file**, not the inbox directory. Watching the directory generates
events for every message write and every archive move — far more noise than needed.

---

## Filesystem Compatibility

Atomic rename is guaranteed only for same-filesystem, same-volume moves on local storage.

| Scenario | Safe? |
| --- | --- |
| Local NTFS (Windows) | Yes |
| Local ext4 / APFS (Linux / macOS) | Yes |
| NFS mount | No — rename may not be atomic |
| SMB / CIFS mount | No — depends on server and client config |
| Cross-volume move | No — becomes copy+delete on both platforms |

If the workspace is on a network filesystem, the contention guarantees do not hold. This
is documented as an out-of-scope constraint in `spec.md` (C1).

---

## Tool Checklist

Before considering a tool implementation complete:

- [ ] Temp-file-then-rename used for message write (never direct write)
- [ ] Nonce from CSPRNG (not `$RANDOM`, PID, or counter)
- [ ] Timestamp in `YYYYMMDDTHHmmssZ` format
- [ ] Signal file written after message, failure tolerated
- [ ] Claim via rename; skip on failure; no retry in same pass
- [ ] Files moved to `archive/` after reading (never deleted)
- [ ] Drain returns all messages in ascending filename order
- [ ] `--help` flag implemented
- [ ] Exit codes: 0 = success, non-zero = tool failure
- [ ] Errors to stderr, output to stdout
