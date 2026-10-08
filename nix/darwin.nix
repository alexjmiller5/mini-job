# nix-darwin module: the job as a long-lived launchd USER agent (`job watch`)
# holding an outbound long poll open against its service. Nothing reaches into
# this machine. Options are generic; the consumer's config supplies only the
# service URL, its subscription and how to read its own credential.
#
# Runs in the login session (gui/<uid> domain) so a credentialCommand can read
# the login Keychain, which ssh-descended shells cannot.
#
# fullDiskAccess: TCC keys grants on code identity, so jobs reading Apple data
# run inside a signed .app at a stable path. Activation keeps one self-signed
# cert (created once) and re-signs every rebuild, so ONE manual grant survives
# updates. The bundle executable must be a real Mach-O (a shebang script fails
# TCC's designated-requirement check on macOS 26), so it is a tiny stub that
# execs the job; FDA inherits across the exec. The grant itself is GUI-only:
# document it in the generated project's README.
self:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.mini-job; # CHANGEME: services.<slug>
  fda = cfg.fullDiskAccess;
  exe = lib.getExe' cfg.package "job"; # CHANGEME: the executable name

  environment = {
    HOME = "/Users/${cfg.user}";
    JOB_SERVICE_URL = cfg.serviceUrl; # CHANGEME: the job's env prefix
    JOB_SUBSCRIPTION_ID = cfg.subscriptionId;
    JOB_STATE_DIR = cfg.stateDir;
  } // lib.optionalAttrs (cfg.credentialCommand != [ ]) {
    JOB_TOKEN_COMMAND = builtins.toJSON cfg.credentialCommand;
  } // cfg.environment;

  appBundle = pkgs.runCommandCC "mini-job-app" { } ''
    mkdir -p "$out/Contents/MacOS"
    cat > "$out/Contents/Info.plist" <<'PLIST'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>${cfg.label}</string>
      <key>CFBundleName</key><string>${fda.appName}</string>
      <key>CFBundleExecutable</key><string>${fda.appName}</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>LSBackgroundOnly</key><true/>
    </dict></plist>
    PLIST
    cat > stub.c <<EOF
    #include <unistd.h>
    int main(int argc, char **argv) {
      argv[0] = (char *)"${exe}";
      execv("${exe}", argv);
      return 127;
    }
    EOF
    $CC -O2 -o "$out/Contents/MacOS/${fda.appName}" stub.c
  '';
  appPath = "/Applications/${fda.appName}.app";
in
{
  options.services.mini-job = {
    enable = lib.mkEnableOption "the CHANGEME long-polling job";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The installed job package.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = "Login user whose session runs the agent and owns its state.";
      example = "local-user";
    };

    serviceUrl = lib.mkOption {
      type = lib.types.str;
      description = "HTTPS origin of the service the job long-polls.";
      example = "https://hub.example.com";
    };

    subscriptionId = lib.mkOption {
      type = lib.types.str;
      description = "The service subscription this job consumes.";
    };

    credentialCommand = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        argv printing this job's own credential, run by the job in the agent's
        login session (e.g. a login-Keychain lookup). Never put the credential
        itself in Nix.
      '';
      example = [ "/usr/bin/security" "find-generic-password" "-s" "mini-job" "-a" "hub" "-w" ];
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/Users/${cfg.user}/.local/state/mini-job"; # CHANGEME
      defaultText = lib.literalExpression ''"/Users/''${user}/.local/state/mini-job"'';
      description = "State and logs (XDG state dir), exported to the job as JOB_STATE_DIR.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra nonsecret job settings (JOB_* variables).";
    };

    label = lib.mkOption {
      type = lib.types.str;
      default = "org.example.mini-job"; # CHANGEME: com.<owner>.<slug>[.<job>], immutable once shipped
      description = "launchd Label (and bundle id when fullDiskAccess is on).";
    };

    fullDiskAccess = {
      enable = lib.mkEnableOption "running inside a signed .app that can hold a Full Disk Access grant";
      appName = lib.mkOption {
        type = lib.types.str;
        default = "MiniJob"; # CHANGEME
        description = "Name of the .app installed in /Applications (the thing granted Full Disk Access).";
      };
      signingIdentity = lib.mkOption {
        type = lib.types.str;
        default = "mini-job-signing"; # CHANGEME
        description = "Common name of the stable self-signed code-signing cert (System keychain), created at activation if absent.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = !(cfg.environment ? JOB_TOKEN) && !(cfg.environment ? JOB_TOKEN_COMMAND);
      message = "Job credentials stay out of Nix settings; use credentialCommand.";
    }];

    environment.systemPackages = [ cfg.package ];

    system.activationScripts.postActivation.text = lib.mkAfter (''
      # launchd opens StandardOutPath before the job runs; create it as the
      # user so no parent (~/.local/state) ends up owned by root.
      /usr/bin/sudo -u ${lib.escapeShellArg cfg.user} /bin/mkdir -p ${lib.escapeShellArg cfg.stateDir}
    '' + lib.optionalString fda.enable ''
      if ! /usr/bin/security find-certificate -c ${lib.escapeShellArg fda.signingIdentity} /Library/Keychains/System.keychain >/dev/null 2>&1; then
        echo "creating code-signing identity ${fda.signingIdentity} (one-time)..."
        _t="$(/usr/bin/mktemp -d)"
        /usr/bin/printf '[req]\ndistinguished_name=dn\nx509_extensions=v3\nprompt=no\n[dn]\nCN=%s\n[v3]\nbasicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n' ${lib.escapeShellArg fda.signingIdentity} > "$_t/req.cnf"
        /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout "$_t/key.pem" -out "$_t/cert.pem" -config "$_t/req.cnf"
        # macOS `security` rejects empty-password PKCS12 (MAC verification fails)
        /usr/bin/openssl pkcs12 -export -inkey "$_t/key.pem" -in "$_t/cert.pem" -out "$_t/id.p12" -passout pass:mini-job-p12
        /usr/bin/security import "$_t/id.p12" -k /Library/Keychains/System.keychain -P mini-job-p12 -T /usr/bin/codesign -A
        # No add-trusted-cert: it needs a GUI prompt, and TCC matches the
        # designated requirement, not trust.
        /bin/rm -rf "$_t"
      fi
      /bin/rm -rf ${lib.escapeShellArg appPath}
      /bin/cp -R ${appBundle} ${lib.escapeShellArg appPath}
      /bin/chmod -R u+w ${lib.escapeShellArg appPath}
      /usr/bin/codesign --force --sign ${lib.escapeShellArg fda.signingIdentity} ${lib.escapeShellArg appPath}
    '');

    launchd.user.agents.mini-job.serviceConfig = { # CHANGEME: agents.<slug>
      Label = cfg.label;
      ProgramArguments = [ (if fda.enable then "${appPath}/Contents/MacOS/${fda.appName}" else exe) "watch" ];
      EnvironmentVariables = environment;
      RunAtLoad = true;
      KeepAlive = true;
      # A crashing job restarts at most every 30 s; the job itself never spins.
      ThrottleInterval = 30;
      ProcessType = "Background";
      WorkingDirectory = cfg.stateDir;
      StandardOutPath = "${cfg.stateDir}/job.log";
      StandardErrorPath = "${cfg.stateDir}/job.log";
    };
  };
}
