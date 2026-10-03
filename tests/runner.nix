{ pkgs ? import <nixpkgs> { } }:
let
  makeRunner = import ../nix/runner.nix;
  job = pkgs.writeShellScriptBin "python" ''
    test "''${CONSUMER_TOKEN-}" = "$EXPECTED_TOKEN"
    test "$1 $2" = "-m job.main"
    test -d "$JOB_STATE_DIR"
  '';
  runner = commands: makeRunner {
    inherit pkgs;
    lib = pkgs.lib;
    venv = job;
    cfg = { stateDir = "/tmp/mini-job-runner-fixture"; credentialCommands = commands; };
  };
in
pkgs.runCommand "mini-job-credential-tests" { } ''
  export EXPECTED_TOKEN=""
  ${runner { }}
  export EXPECTED_TOKEN="fixture with spaces"
  ${runner { CONSUMER_TOKEN = [ "${pkgs.coreutils}/bin/printf" "%s" "fixture with spaces" ]; }}
  if ${runner { CONSUMER_TOKEN = [ "${pkgs.coreutils}/bin/false" ]; }}; then
    echo "Failed credential command must prevent job execution" >&2
    exit 1
  fi
  rmdir /tmp/mini-job-runner-fixture
  touch $out
''
