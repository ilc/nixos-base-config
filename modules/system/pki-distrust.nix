# CA roots we no longer trust, on every host.
#
# eMudhra (emSign), October 2026: the private keys of eight of its intermediate
# CAs were trivially weak (one was the number 4), so anyone could mint
# certificates that chain to them. Mozilla removed the affected roots in NSS
# 3.131.1; nixpkgs still ships an older bundle, so remove them here until it
# catches up. This follows Mozilla's list exactly: emSign Root CA - G1 (RSA,
# key not compromised) stays trusted, as Mozilla keeps it, because eMudhra is
# moving its remaining certificates (InCommon's) onto it. Drop each entry once
# the packaged bundle, Node and Chromium no longer carry that root.
#
# Three trust stores need it, because three different things decide trust:
#   1. The system bundle (/etc/ssl/certs): curl, git, nix, Python, Go, ...
#      Done upstream: cacert 3.131.1 dropped these roots, and its build
#      refuses to blacklist a root it no longer has, so nothing is set here.
#   2. Node, which carries its own compiled-in root list and ignores the
#      system bundle unless told otherwise. --use-openssl-ca makes it read the
#      system bundle instead of its own.
#   3. Chromium, whose root store is compiled in and, in ungoogled-chromium,
#      never updated (no component updater), so it gets a managed policy.
# Firefox needs nothing here: Mozilla distrusted these through its own
# updates and revocation lists. Claude Code is a Bun binary that only trusts
# its compiled-in list and ignores all of the above; from 2.1.310 that list
# matches Mozilla's.
{ pkgs, lib, ... }:

let
  distrusted = [
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];

  # Chromium's CADistrustedCertificates wants each certificate as base64 DER.
  # The packaged bundle no longer carries these roots (cacert 3.131.1), so
  # they are kept here, copied from the last Mozilla bundle that had them
  # (nixpkgs cacert 3.126). Chromium 156's compiled-in store still trusts
  # emSign ECC Root CA - G3; C1 and C3 were never in it. Fail the
  # build if any name is missing from that file, so a list and file that drift
  # apart are noticed instead of silently skipped.
  chromiumPolicy = pkgs.runCommand "chromium-ca-distrust.json"
    { nativeBuildInputs = [ pkgs.openssl pkgs.jq ]; } ''
    bundle=${./pki-distrust-roots.pem}
    certs=()
    for name in ${lib.escapeShellArgs distrusted}; do
      pem=$(awk -v n="$name" '$0 == n {f = 1; next} f && /BEGIN CERT/ {p = 1}
        p {print} p && /END CERT/ {exit}' "$bundle")
      [ -n "$pem" ] || { echo "no root named '$name' in $bundle" >&2; exit 1; }
      certs+=("$(printf '%s\n' "$pem" | openssl x509 -outform der | base64 -w0)")
    done
    jq -n '{CADistrustedCertificates: $ARGS.positional}' --args "''${certs[@]}" > $out
  '';
in
{
  environment.sessionVariables.NODE_OPTIONS = "--use-openssl-ca";

  environment.etc."chromium/policies/managed/ca-distrust.json".source = chromiumPolicy;
}
