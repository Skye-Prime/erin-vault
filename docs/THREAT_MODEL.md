# ERIN Vault — Threat Model

## What it protects

**The realistic threat:** you want an AI agent to do authenticated work on
your machine, but chat logs, tool outputs, and terminal scrollback are all
places a password can leak — and once it's in a log, it's compromised.
ERIN Vault removes the secret from that entire path:

- Credentials are stored encrypted at rest (Fernet = AES-128-CBC + HMAC-SHA256).
- The master key lives in the macOS Keychain when available, otherwise in a
  `0600` file under `~/.erin-vault/` (`700` directory). No other user on the
  machine can read either file.
- `run` injects the secret directly into the child process's PTY. The agent
  only ever sees output with the value replaced by `[REDACTED]`.
- `serve-store` is a one-shot listener: single-use 6-digit PIN, binds
  localhost by default, shuts down after one submission or 10 minutes, and
  the submitted value goes straight into the encrypted vault — never into a
  log (HTTP logging is disabled).
- The 2FA code file is created with `0600` permissions and deleted after use.

## Local-only guarantee (verified before release)

The storage database cannot accidentally sync or share passwords because
there is no code path that sends it anywhere:

- The script makes **zero outbound network connections**. Verified by audit:
  no `requests`, no `urllib.request`, no raw sockets dialing out, no
  subprocess calls to `curl`/upload tools. The only socket in the program is
  the `serve-store` *listener*, which defaults to `127.0.0.1`.
- The vault file and master key live under `~/.erin-vault/` and are
  referenced only by local filesystem paths. Nothing in the program reads,
  copies, or transmits them off-machine.

## Out of scope (non-goals)

- **A compromised machine.** If malware runs as your user (or root), it can
  read the vault files while they're unlocked — same as it could read your
  SSH keys or browser cookies. ERIN Vault is not a hardware security module.
- **Physical access / unlocked screen.** Lock your screen.
- **Cloud-synced home directories.** Do not put `~/.erin-vault/` inside
  Dropbox, iCloud Drive, or any synced folder. A synced *encrypted* blob is
  still only as safe as your sync provider and your master key hygiene.
- **Shoulder surfing the phone form.** `serve-store` shows the password
  field as dots, but someone watching the screen sees what's typed.
- **The human relaying the PIN insecurely.** The 6-digit PIN is single-use
  and expires in 10 minutes, but treat the relay channel (chat with your
  agent) as semi-trusted.

## Operational advice

- Use full-disk encryption and a screen lock.
- Rotate a credential with `erin-vault store <same-name>` after any incident.
- Back up `~/.erin-vault/` like you back up SSH keys: encrypted, offline,
  and never in a repo.
