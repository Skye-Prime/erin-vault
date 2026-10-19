# ERIN Vault

A local-only encrypted credential broker for AI agents.

Your agent needs to run authenticated commands — log in to developer
accounts, sign builds, hit private APIs. You don't want to paste passwords
into a chat window where they'd be logged forever, and you don't want the
agent holding raw secrets it might echo back.

ERIN Vault fixes that: you store each credential **once**, encrypted on your
own machine. The agent triggers commands *through* the vault. The vault types
the secret into the command's prompts inside a PTY and scrubs the value out
of all output before the agent sees it. The agent never sees your passwords.

## Install

Hand this repo to your agent and say **"please install this"** — it will
follow [`AGENTS.md`](AGENTS.md). Or do it yourself in 30 seconds:

```bash
./install.sh
# or manually:
#   python3 -m pip install --user cryptography
#   cp erin-vault ~/bin/erin-vault && chmod +x ~/bin/erin-vault
```

Requires Python 3.9+ and the `cryptography` package. macOS or Linux.

## Usage

```bash
# Store a credential (hidden prompts, double-entry confirm)
erin-vault store apple-id --username you@example.com

# Or store it from your phone: prints a URL + one-time encryption code.
# The page encrypts the password in your browser BEFORE it travels —
# a network listener sees only ciphertext. Localhost-only, one
# submission, 10-minute expiry.
erin-vault serve-store apple-id

# See what's stored (names only, never values)
erin-vault list

# Run an authenticated command — the vault injects the secret
# into prompts and filters it from all output
erin-vault run apple-id -- eas build --platform ios --profile production

# With 2FA: the vault waits, you drop the code at the pipe path
erin-vault run apple-id --2fa-pipe /tmp/my-2fa -- some-command

# Remove one
erin-vault delete apple-id
```

App-specific yes/no prompts (like Apple's "reuse this distribution
certificate?") are handled by the `EXTRA_PROMPT_HANDLERS` list at the top of
the script — extend it with your own tools' prompts.

## Local-only guarantee

- The encrypted database (`~/.erin-vault/vault.enc`, Fernet/AES-128) and the
  master key (macOS Keychain, or a `0600` file) **never leave the machine**.
- The script makes **zero outbound network connections**. The only socket it
  ever opens is the optional `serve-store` listener, which binds `127.0.0.1`
  by default — and `serve-store` is **end-to-end encrypted**: the password is
  encrypted in the browser (PBKDF2-SHA256 → AES-256-GCM) with a one-time
  code before it travels, so even a network listener sees only ciphertext.
- See [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) for what it protects
  against — and what it doesn't.

## License

MIT — see [LICENSE](LICENSE).
