{
  description = "CHANGEME: scheduled job on the mac mini";

  outputs = { self, ... }: {
    darwinModules.default = import ./nix/darwin.nix;
  };
}
