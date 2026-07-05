# Canonical secrets manifest — op:// references only, SAFE to commit.
# Local dev:  op run --env-file=.env.tpl -- <cmd>   (see justfile)
# On the mini: scripts/run.sh injects these via the Keychain-held op token.
#
# CHANGEME — one line per secret, e.g.:
# NOTION_API_KEY=op://personal-infra/notion-api/credential
