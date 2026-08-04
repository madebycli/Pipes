{
  lib,
  stdenvNoCC,
  python3,
  ncurses,
}:

stdenvNoCC.mkDerivation {
  pname = "pipes-sh-python";
  version = "3.0.0";

  src = lib.cleanSource ../.;
  strictDeps = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        libexec="$out/libexec/pipes"
        mkdir -p "$libexec" "$out/bin" "$out/share/man/man6"
        install -m644 pipes_sh.py "$libexec/pipes_sh.py"
        sed -i '1{/^#!/d;}' "$libexec/pipes_sh.py"
        install -m644 pipes.6 "$out/share/man/man6/pipes.6"

        cat > "$out/bin/pipes" <<PY
    #!${python3.interpreter}
    import os
    import runpy

    terminfo = "${ncurses}/share/terminfo"
    current = os.environ.get("TERMINFO_DIRS")
    os.environ["TERMINFO_DIRS"] = terminfo if not current else f"{terminfo}:{current}"
    runpy.run_path("$libexec/pipes_sh.py", run_name="__main__")
    PY
        chmod +x "$out/bin/pipes"

        runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test -x "$out/bin/pipes"
    test ! -e "$out/bin/pipes.sh"
    test -f "$out/share/man/man6/pipes.6.gz"
    test ! -e "$out/share/man/man6/pipes.sh.6"
    test ! -e "$out/share/man/man6/pipes.sh.6.gz"
    test "$(head -n1 "$out/bin/pipes")" = '#!${python3.interpreter}'
    test -d "${ncurses}/share/terminfo"

    find "$out" -type f -exec sha256sum {} + | sort > "$TMPDIR/out-before"
    TERM=xterm-256color "$out/bin/pipes" --help >/dev/null
    test "$(TERM=xterm-256color "$out/bin/pipes" --version)" = "pipes 3.0.0"
    TERM=xterm-256color "$out/bin/pipes" --self-test | grep -q '^pipes self-test: PASS$'
    TERM=xterm-256color TERMINFO_DIRS="${ncurses}/share/terminfo" \
      ${python3.interpreter} -O "$out/libexec/pipes/pipes_sh.py" --self-test \
      | grep -q '^pipes self-test: PASS$'

    if grep -R -E '/usr/bin/python3|/usr/bin/env|/home/[^/]+|~/|/nix/store/.*/source' \
      "$out/bin" "$out/libexec"; then
      echo "non-hermetic runtime path found in Pipes output" >&2
      exit 1
    fi

    find "$out" -type f -exec sha256sum {} + | sort > "$TMPDIR/out-after"
    cmp "$TMPDIR/out-before" "$TMPDIR/out-after"

    runHook postInstallCheck
  '';

  meta = {
    description = "Unofficial Python rewrite of the pipes.sh terminal screensaver";
    homepage = "https://github.com/madebycli/Pipes";
    license = lib.licenses.mit;
    mainProgram = "pipes";
    platforms = lib.platforms.linux;
  };
}
