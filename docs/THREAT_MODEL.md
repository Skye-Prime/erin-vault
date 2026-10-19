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
- `serve-store` is a one-shot listener: no URL token (nothing secret in the
  link), binds localhost by default, shuts down after one successful
  submission, 25 failed attempts, or 10 minutes, and the submitted value
  arrives **already encrypted** (see below) and goes straight into the
  encrypted vault — never into a log (HTTP logging is disabled).

## End-to-end encryption on serve-store

The one-time web form does not trust the network. When you run
`serve-store`, the vault prints a URL and a one-time **encryption code**
(12 unambiguous characters, ~60 bits of entropy). The human opens the URL
and types the code into the form along with the password. The page then:

1. Derives a 256-bit key from the code with PBKDF2-HMAC-SHA256 (600,000
   iterations) and a fresh 16-byte salt.
2. Encrypts `{"username": …, "password": …}` with AES-256-GCM (or
   ChaCha20-Poly1305 on browsers without WebCrypto), binding the
   ciphertext to the credential name as associated data.
3. POSTs only `{suite, salt, iv, ciphertext}`. The server re-derives the
   key and decrypts; a wrong code or any tampering fails authentication
   and is rejected.

What this means: a **passive network listener** sees only random-looking
bytes — the password is never transmitted or stored in plaintext, and the
code that unlocks it travels via your chat with the agent, a separate
channel. Brute-forcing the code from captured ciphertext would take
millions of GPU-years (60-bit code × 600k-iteration KDF).

Honest limits: this defeats passive eavesdropping, not an **active**
attacker rewriting the form's JavaScript in transit over plain HTTP. If
your network is actively hostile, bind `serve-store` to localhost (nothing
leaves the machine) or reach it through an encrypted tunnel such as
Tailscale/WireGuard, which authenticates the transport. The page also runs
a cryptographic self-test on load and **fails closed** — the submit button
stays disabled unless every test vector passes.

## Open design: public code does not weaken the encryption

This repository is public, and that is not a problem — it is the point.
The encryption follows **Kerckhoffs's principle**: the system stays secure
even when the attacker has read every line of the code, because security
rests on **random per-install secrets**, never on secret logic:

- At rest: Fernet (AES-128-CBC + HMAC-SHA256) under a random 256-bit master
  key created on first use. Reading the code tells an attacker the
  *algorithm*, but the key exists only on your machine.
- In transit (`serve-store`): a fresh random salt, IV, and one-time code
  per session. The code's 60 bits of entropy plus the 600k-iteration KDF
  are what resist brute force — not obscurity.
- All primitives (AES-GCM, ChaCha20-Poly1305, PBKDF2, SHA-256, Fernet) are
  standard, widely-vetted constructions — deliberately no homebrew crypto.

What to check when auditing: that keys/salts/IVs come from a CSPRNG
(`secrets` / `os.urandom` / `crypto.getRandomValues`), that ciphertexts are
authenticated (GCM/Poly1305 tags, Fernet HMAC) before use, and that no
secret is ever logged. Those are the properties that matter; the source
being public changes none of them.
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
- **The human relaying the code insecurely.** The encryption code is
  one-time and expires in 10 minutes, but treat the relay channel (chat
  with your agent) as semi-trusted: anyone who captures *both* the code
  and the network traffic can decrypt that one submission.

## Operational advice

- Use full-disk encryption and a screen lock.
- Rotate a credential with `erin-vault store <same-name>` after any incident.
- Back up `~/.erin-vault/` like you back up SSH keys: encrypted, offline,
  and never in a repo.
