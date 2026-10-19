#!/bin/bash
# ERIN Vault installer.
# Or: hand this repo to your agent and say "please install this".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 -c "import cryptography" 2>/dev/null \
  || python3 -m pip install --user cryptography

mkdir -p "$HOME/bin"
cp "$SCRIPT_DIR/erin-vault" "$HOME/bin/erin-vault"
chmod +x "$HOME/bin/erin-vault"

case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) echo "NOTE: add \$HOME/bin to your PATH:"; echo '  export PATH="$HOME/bin:$PATH"';;
esac

"$HOME/bin/erin-vault" --version
echo "Installed. Next: erin-vault list"
