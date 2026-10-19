# ERIN Vault — Agent Install Guide

> You are an AI agent. A human has handed you this repository and said
> "please install this." Follow this guide top to bottom. Do not skip the
> verification steps.

## What this is

ERIN Vault is a small command-line tool that lives on one machine and holds
that machine's passwords encrypted. You (the agent) trigger authenticated
commands *through* the vault: it types the username/password into the
command's prompts inside a PTY and scrubs the values out of all output
before you ever see them. You never see, log, or store the secrets.

## Step 1 — Prerequisites

- Python 3.9+
- The `cryptography` package: `python3 -m pip install --user cryptography`
- macOS or Linux. On macOS the master key goes into the Keychain when
  possible; over SSH the Keychain is usually locked and the vault
  automatically falls back to a `0600` key file — that is expected, not an
  error.

## Step 2 — Install

1. Copy the `erin-vault` script to `~/bin/erin-vault` (create `~/bin` if
   needed) or `/usr/local/bin/erin-vault`.
2. `chmod +x` it and make sure its directory is on `PATH`.
   (Or just run `./install.sh` — it does all of the above.)
3. Verify:
   - `erin-vault --version` → `erin-vault 1.1.0`
   - `erin-vault list` → `No credentials stored.`
   - The first *write* creates the master key. Confirm the directory is
     `~/.erin-vault` with `700` permissions.

## Step 3 — Store the first credential

Pick the method that fits the human:

- **Sitting at the machine:** `erin-vault store <name> [--username user@example.com]`
  Hidden prompts, double-entry confirmation. Nothing is echoed.
- **From a phone or another device:** `erin-vault serve-store <name>`
  Prints `VAULT_URL:` and `VAULT_CODE:`. Relay both to the human; they open
  the URL, type the **encryption code** into the form along with the secret,
  and the page **encrypts the password in their browser before anything
  travels** (PBKDF2-SHA256 600k → AES-256-GCM; a verified ChaCha20-Poly1305
  fallback covers browsers without WebCrypto). A network listener sees only
  ciphertext — the code itself travels via your chat, a separate channel.
  The server binds **localhost only** by default and shuts down after one
  submission, 25 failed attempts, or 10 minutes. If the human's browser is
  on a *different* device on a private mesh network (e.g. Tailscale),
  re-run with `--bind <this-machine's-private-IP>` — the mesh's own
  encryption then adds a second layer.
- Then run `erin-vault list` to confirm the *name* is stored. You will never
  see the value — that is the point.

## Step 4 — Use it

```
erin-vault run <name> [--username override] [--2fa-pipe /tmp/code] -- <command...>
```

- Injects the username on identity prompts and the credential on password
  prompts, inside a PTY.
- Filters both values from **all** output before you see it. You will see
  `[REDACTED]` where they appeared. Do not try to work around this.
- **2FA:** pass `--2fa-pipe <path>`. When the vault prints
  `2FA code needed — waiting...`, ask the human for the code, write it to
  that path as plain text, and the vault injects it and deletes the file.
- **App-specific yes/no prompts:** extend `EXTRA_PROMPT_HANDLERS` near the
  top of the script — each entry is `(regex, reply, note)` and fires at most
  once per run. The included examples drive Apple's/EAS interactive prompts;
  replace them with whatever your tools ask.

## Rules you must follow

1. **Never print, log, or repeat a credential value.** The vault redacts
   them from output; keep it that way. Never attempt to bypass the filter,
   and never ask the human to paste a secret into chat when a vault method
   exists.
2. **The vault database is local-only.** Never copy `~/.erin-vault/` to
   another machine, into cloud storage, or into a repo. Never `cat` the
   vault file into chat. Never `serve-store --bind 0.0.0.0`.
3. `serve-store` binds localhost by default — keep it that way unless the
   human explicitly asks for remote entry, and then only on a private
   interface (Tailscale/WireGuard), never a public one.
4. If the human rotates a secret, `erin-vault store <same-name>` overwrites it.
5. If a command fails, debug from the redacted output like you normally
   would. The exit code is passed through (`[erin-vault: exited N]`).

## Troubleshooting

- `No module named 'cryptography'` → `python3 -m pip install --user cryptography`
- `Vault decrypt failed` → the master key doesn't match the vault file
  (Keychain entry vs. `~/.erin-vault/.master-key` mismatch, or the vault
  came from another machine — it won't work there, by design).
- `serve-store` unreachable from a phone → re-run with `--bind` set to this
  machine's private-network IP, and confirm the phone is on the same
  private network.
- On macOS over SSH, `security` errors like "User interaction is not
  allowed" are expected — the vault falls back to the local key file
  automatically.
