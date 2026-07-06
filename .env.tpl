# Canonical secrets manifest — 1Password secret references only, SAFE to commit.
# Local dev:  op run --env-file=.env.tpl -- <cmd>   (see justfile)
# On the mini: scripts/run.sh injects these via the Keychain-held op token.
#
# CHANGEME — one line per secret. Reference syntax (no spaces):
#   VAR_NAME=op :// vault / item / field   <- remove the spaces; spelled out
#   because a literal reference in a comment breaks `op inject`.
