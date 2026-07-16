# Canonical secrets manifest — 1Password secret references only, SAFE to commit.
# Local dev:  op run --env-file=.env.tpl -- <cmd>   (see justfile)
# On the mini: the nix module's runner injects these (token from agenix or Keychain).
#
# CHANGEME — one line per secret. ALL of this app's env vars are fields of
# ONE item titled "<Project> ENV" in the project vault (field name = var name):
#   VAR_NAME=op :// <Vault> / <Project> ENV / VAR_NAME   <- remove the spaces;
#   spelled out because a literal reference in a comment breaks `op inject`.
