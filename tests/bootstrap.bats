#!/usr/bin/env bats
# Unit tests for bootstrap.sh.  Run:  bats tests/
#
# bootstrap.sh guards main() behind a "sourced vs executed" check, so sourcing it
# here loads the functions WITHOUT running any installs — that's what makes the
# pure functions unit-testable in isolation.

setup() {
  source "${BATS_TEST_DIRNAME}/../bootstrap.sh"
}

@test "pkglist strips comments and blank lines" {
  local f; f="$(mktemp)"
  printf '# a comment\n\nzsh\n   # indented comment\ngit\n' > "$f"
  run pkglist "$f"
  rm -f "$f"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "zsh" ]
  [ "${lines[1]}" = "git" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "is_wsl detects a WSL kernel string" {
  local f; f="$(mktemp)"
  printf 'Linux version 5.15.0-microsoft-standard-WSL2\n' > "$f"
  WSL_VERSION_FILE="$f" run is_wsl
  rm -f "$f"
  [ "$status" -eq 0 ]
}

@test "is_wsl is false on a normal kernel string" {
  local f; f="$(mktemp)"
  printf 'Linux version 6.12.0-el10.x86_64\n' > "$f"
  WSL_VERSION_FILE="$f" run is_wsl
  rm -f "$f"
  [ "$status" -ne 0 ]
}

@test "install_claude_code is a no-op when claude is already on PATH (mocked)" {
  # Put a fake 'claude' on PATH; the guard should short-circuit with no output.
  local bin; bin="$(mktemp -d)"
  printf '#!/bin/sh\n' > "$bin/claude"; chmod +x "$bin/claude"
  PATH="$bin:$PATH" run install_claude_code
  rm -rf "$bin"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install_awscli is a no-op when aws is already on PATH (mocked)" {
  # A fake 'aws' on PATH should short-circuit before any arch/download work.
  local bin; bin="$(mktemp -d)"
  printf '#!/bin/sh\n' > "$bin/aws"; chmod +x "$bin/aws"
  PATH="$bin:$PATH" run install_awscli
  rm -rf "$bin"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "install_sqlcmd is a no-op when sqlcmd is already on PATH (mocked)" {
  local bin; bin="$(mktemp -d)"
  printf '#!/bin/sh\n' > "$bin/sqlcmd"; chmod +x "$bin/sqlcmd"
  PATH="$bin:$PATH" run install_sqlcmd
  rm -rf "$bin"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "setup_postgresql is a no-op on Linux without postgresql-setup (mocked)" {
  # A minimal PATH with only a fake `uname` (and no postgresql-setup) must make
  # the function return 0 silently — no sudo, no service calls.
  local bin; bin="$(mktemp -d)"
  printf '#!/bin/sh\necho Linux\n' > "$bin/uname"; chmod +x "$bin/uname"
  PATH="$bin" run setup_postgresql
  rm -rf "$bin"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "sourcing bootstrap.sh does not run main (the guard works)" {
  # If sourcing ran main it would emit logs / try to install. It must not.
  run bash -c "source '${BATS_TEST_DIRNAME}/../bootstrap.sh' && echo SOURCED_OK"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = "SOURCED_OK" ]
}
