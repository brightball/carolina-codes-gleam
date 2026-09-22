import gleam/bit_array
import gleam/erlang/charlist
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub fn image_is_pinned_erlang_and_ignores_build_context_test() {
  let docker = must_read("Dockerfile")
  let ignore = must_read(".dockerignore")
  let final = final_stage(docker)
  assert string.contains(
    docker,
    "ghcr.io/gleam-lang/gleam:v1.18.1-erlang-alpine",
  )
  assert string.contains(docker, "erlang:29.1.0.0-alpine")
  assert string.contains(docker, "strip-otel-elixir.sh")
  assert !string.contains(docker, "nightly")
  assert !string.contains(docker, "postgresql-client")
  assert !string.contains(docker, "curl")
  assert string.starts_with(string.trim(final), "erlang:29.1.0.0-alpine")
  assert !string.contains(final, "gleam")
  assert !string.contains(final, "apk")
  assert !string.contains(final, "apt-get")
  assert !string.contains(final, "postgresql-client")
  assert !string.contains(final, "curl")
  assert string.contains(ignore, "build/")
}

pub fn fly_keeps_one_machine_and_suspends_test() {
  let src = must_read("fly.toml")
  assert string.contains(src, "auto_stop_machines = \"suspend\"")
  assert !string.contains(src, "auto_stop_machines = \"stop\"")
  assert !string.contains(src, "auto_stop_machines = \"off\"")
  assert string.contains(src, "min_machines_running = 1")
  assert !string.contains(src, "min_machines_running = 0")
  assert string.contains(src, "memory = \"512mb\"")
  assert string.contains(src, "cpu_kind = \"shared\"")
  assert string.contains(src, "cpus = 1")
  assert string.contains(src, "internal_port = 8080")
  assert string.contains(src, "path = \"/health\"")
  assert string.contains(src, "method = \"GET\"")
  assert string.contains(src, "ERL_AFLAGS = \"+S 1:1\"")
}

pub fn strip_otel_elixir_removes_elixir_application_test() {
  let cmd =
    "set -eu\n"
    <> "root=\"$(pwd)/build/otel-strip-test\"\n"
    <> "rm -rf \"$root\"\n"
    <> "mkdir -p \"$root/lib/opentelemetry_api/ebin\"\n"
    <> "app=\"$root/lib/opentelemetry_api/ebin/opentelemetry_api.app\"\n"
    <> "printf '%s\\n' \"{application,opentelemetry_api,[{modules,['Elixir.OpenTelemetry','Elixir.OpenTelemetry.Baggage',opentelemetry,otel_tracer]},{applications,[kernel,stdlib,elixir]},{vsn,\\\"1.5.0\\\"}]}.\" > \"$app\"\n"
    <> "printf 'beam\\n' > \"$root/lib/opentelemetry_api/ebin/Elixir.OpenTelemetry.beam\"\n"
    <> "mkdir -p \"$root/elixir/ebin\" \"$root/eex/ebin\" \"$root/mix/ebin\" \"$root/logger/ebin\"\n"
    <> "printf 'elixir\\n' > \"$root/elixir/ebin/elixir.app\"\n"
    <> "printf '%s\\n' '# SPDX' '' '#!/bin/sh' 'set -eu' > \"$root/entrypoint.sh\"\n"
    <> "sh scripts/strip-otel-elixir.sh \"$root\"\n"
    <> "head -1 \"$root/entrypoint.sh\" | grep -qx '#!/bin/sh'\n"
    <> "test ! -d \"$root/elixir\"\n"
    <> "test ! -d \"$root/eex\"\n"
    <> "test ! -d \"$root/mix\"\n"
    <> "test ! -d \"$root/logger\"\n"
    <> "grep -q elixir \"$app\" && echo ELIXIR_STILL_PRESENT && exit 1 || true\n"
    <> "grep -q opentelemetry \"$app\"\n"
    <> "test ! -e \"$root/lib/opentelemetry_api/ebin/Elixir.OpenTelemetry.beam\"\n"
  let #(code, out) = sh(cmd)
  assert code == 0
  assert !string.contains(out, "ELIXIR_STILL_PRESENT")
}

pub fn precommit_yaml_has_five_distinct_checks_test() {
  let src = must_read(".pre-commit-config.yaml")
  assert string.contains(src, "id: local-tests")
  assert string.contains(src, "entry: make test")
  assert string.contains(src, "id: sast")
  assert string.contains(src, "entry: make sast")
  assert string.contains(src, "id: audit")
  assert string.contains(src, "entry: make audit")
  assert string.contains(src, "id: gitleaks")
  assert string.contains(src, "entry: make secrets")
  assert string.contains(src, "id: format")
  assert string.contains(src, "entry: make format")
}

pub fn cactus_precommit_has_five_distinct_actions_test() {
  let src = must_read("gleam.toml")
  assert string.contains(src, "[cactus.pre-commit]")
  assert string.contains(src, "args = [\"test\"]")
  assert string.contains(src, "args = [\"sast\"]")
  assert string.contains(src, "args = [\"audit\"]")
  assert string.contains(src, "args = [\"secrets\"]")
  assert string.contains(src, "args = [\"format\"]")
  assert string.contains(src, "go_over = ")
  assert string.contains(src, "[go-over]")
}

pub fn makefile_wires_the_five_tool_entrypoints_test() {
  let src = must_read("Makefile")
  assert string.contains(src, "gleam test")
  assert string.contains(src, "scripts/sast.sh")
  assert string.contains(src, "gleam run -m go_over")
  assert string.contains(src, "gitleaks detect --source .")
  assert !string.contains(src, "--no-git")
  assert string.contains(src, "gleam format --check")
}

pub fn sast_script_scans_this_app_not_hex_packages_test() {
  let src = must_read("scripts/sast.sh")
  assert string.contains(src, "tools/pest/pest.erl")
  assert string.contains(src, "-e -r src")
  assert string.contains(src, "carolina_codes_gleam")
  assert !string.contains(src, "build/packages")
}

pub fn mise_pins_gitleaks_and_named_check_tasks_test() {
  let src = must_read("mise.toml")
  assert string.contains(src, "gitleaks")
  assert string.contains(src, "make test")
  assert string.contains(src, "make sast")
  assert string.contains(src, "make audit")
  assert string.contains(src, "make secrets")
  assert string.contains(src, "make format")
}

pub fn gitea_workflow_has_one_parallel_job_per_check_test() {
  let src = must_read(".gitea/workflows/precommit.yml")
  let setup = must_read("scripts/ci-setup.sh")
  let jobs = workflow_jobs(src)
  let names = list.map(jobs, fn(job) { job.0 })
  let prepare = must_job(jobs, "prepare")
  let checks = ["test", "sast", "deps-audit", "gitleaks", "format"]

  assert names == ["prepare", ..checks]
  assert string.contains(src, "GITHUB_TOKEN: ${{ github.token }}")
  assert string.contains(src, "cancel-in-progress: true")
  assert !has_command_line(src, "git init")
  assert !has_command_line(src, "init.defaultBranch")
  assert count_needle(src, "make check") == 0
  assert jobs_with(jobs, "uses: actions/upload-artifact@v4") == []
  assert jobs_with(jobs, "uses: actions/download-artifact@v4") == []

  assert string.contains(setup, "mise install")
  assert !string.contains(setup, "git clone")
  let assert Ok(#(before_install, _)) = string.split_once(setup, "mise install")
  assert string.contains(before_install, "unset GITHUB_TOKEN")

  assert token_clones(prepare)
  assert string.contains(prepare, "bash scripts/ci-setup.sh")
  assert string.contains(prepare, "gleam deps download")
  assert string.contains(prepare, "bash scripts/ci-pack-env.sh")
  assert string.contains(prepare, "actions/upload-artifact@v3")
  assert string.contains(prepare, "name: prep-env")
  assert string.contains(prepare, "prep-env.tar.gz")
  assert !string.contains(prepare, "needs:")
  assert !string.contains(prepare, "ci-restore-env.sh")
  assert !runs_make_check(prepare)

  assert jobs_with(jobs, clone_recipe) == ["prepare"]
  assert jobs_with(jobs, "bash scripts/ci-setup.sh") == ["prepare"]
  assert jobs_with(jobs, "bash scripts/ci-pack-env.sh") == ["prepare"]
  assert jobs_with(jobs, "mise install") == []
  assert jobs_with(jobs, "gleam deps download") == ["prepare"]
  assert jobs_with(jobs, "actions/upload-artifact@v3") == ["prepare"]
  assert jobs_with(jobs, "make test") == ["test"]
  assert jobs_with(jobs, "make sast") == ["sast"]
  assert jobs_with(jobs, "make audit") == ["deps-audit"]
  assert jobs_with(jobs, "make secrets") == ["gitleaks"]
  assert jobs_with(jobs, "make format") == ["format"]

  let test_job = must_job(jobs, "test")
  assert string.contains(test_job, "postgres:16")
  assert string.contains(test_job, "DATABASE_URL")

  list.each(checks, fn(name) {
    let body = must_job(jobs, name)
    assert string.contains(body, "needs: prepare")
    assert count_needle(body, "needs:") == 1
    assert string.contains(body, "actions/download-artifact@v3")
    assert string.contains(body, "name: prep-env")
    assert string.contains(body, "prep-env.tar.gz")
    assert string.contains(body, "tar -xzf")
    assert string.contains(body, "bash ./ci-restore-env.sh")
    assert !token_clones(body)
    assert !string.contains(body, "ci-setup.sh")
    assert !string.contains(body, "ci-pack-env.sh")
    assert !string.contains(body, "mise install")
    assert !string.contains(body, "gleam deps download")
    assert !string.contains(body, "git clone")
    assert !string.contains(body, "ci-checkout.sh")
    list.each(checks, fn(other) {
      case other == name {
        True -> Nil
        False -> {
          assert !string.contains(body, "needs: " <> other)
          Nil
        }
      }
    })
  })
}

pub fn ci_pack_restore_scripts_transfer_env_without_reinstall_test() {
  let pack = must_read("scripts/ci-pack-env.sh")
  let restore = must_read("scripts/ci-restore-env.sh")
  assert string.contains(pack, "prep-workspace.tar.gz")
  assert string.contains(pack, "prep-toolchain.tar.gz")
  assert string.contains(pack, "prep-env.tar.gz")
  assert string.contains(pack, ".local/share/mise")
  assert string.contains(pack, "ci-restore-env.sh")
  assert string.contains(pack, "missing .git")
  assert string.contains(pack, "x-access-token:")
  assert !string.contains(pack, "--exclude=./.git")
  assert !string.contains(pack, "git clone")
  assert !string.contains(pack, "mise install")
  assert !string.contains(pack, "ci-setup.sh")
  assert string.contains(restore, "tar -xzf")
  assert string.contains(restore, "prep-workspace.tar.gz")
  assert string.contains(restore, "prep-toolchain.tar.gz")
  assert string.contains(restore, "-C \"${HOME}\"")
  assert !string.contains(restore, "git clone")
  assert !string.contains(restore, "mise install")
  assert !string.contains(restore, "ci-setup.sh")
  assert !string.contains(restore, "gleam deps download")
}

pub fn packed_workspace_is_gitleaks_runnable_without_clone_token_test() {
  let makefile = must_read("Makefile")
  assert string.contains(makefile, "gitleaks detect --source .")
  assert !string.contains(makefile, "--no-git")

  let cmd =
    "set -eu\n"
    <> "export PATH=\"${HOME}/.local/bin:${HOME}/.local/share/mise/shims:${PATH}\"\n"
    <> "root=\"$(pwd)\"\n"
    <> "fx=\"${root}/build/ci-pack-gitleaks\"\n"
    <> "rm -rf \"${fx}\"\n"
    <> "mkdir -p \"${fx}/scripts\"\n"
    <> "cp scripts/ci-pack-env.sh scripts/ci-restore-env.sh \"${fx}/scripts/\"\n"
    <> "chmod +x \"${fx}/scripts/ci-pack-env.sh\"\n"
    <> "cd \"${fx}\"\n"
    <> "git init >/dev/null\n"
    <> "git config user.email pack@test\n"
    <> "git config user.name pack\n"
    <> "printf 'hello\\n' > README\n"
    <> "git add README\n"
    <> "git commit -q -m init\n"
    <> "git remote add origin 'https://x-access-token:s3cret-token@gitea.example/org/repo.git'\n"
    <> "bash scripts/ci-pack-env.sh workspace\n"
    <> "mkdir out\n"
    <> "tar -xzf prep-workspace.tar.gz -C out\n"
    <> "test -d out/.git\n"
    <> "test -f out/README\n"
    <> "if grep -R -q 'x-access-token:' out/.git; then echo TOKEN_LEAKED; exit 1; fi\n"
    <> "origin=\"$(git -C out remote get-url origin)\"\n"
    <> "test \"${origin}\" = 'https://gitea.example/org/repo.git'\n"
    <> "cd out\n"
    <> "gitleaks detect --source . --verbose --no-banner\n"
  let #(code, out) = sh(cmd)
  assert code == 0
  assert !string.contains(out, "TOKEN_LEAKED")
  assert !string.contains(out, "not a git repository")
  assert !string.contains(out, "0 commits scanned")
  assert string.contains(out, "commits scanned")
}

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(BitArray, String)

@external(erlang, "os", "cmd")
fn os_cmd(command: charlist.Charlist) -> charlist.Charlist

fn sh(cmd: String) -> #(Int, String) {
  let wrapped = "( " <> cmd <> "\n) 2>&1; printf '__EXIT__%s\\n' \"$?\""
  let out = charlist.to_string(os_cmd(charlist.from_string(wrapped)))
  case string.split(out, "__EXIT__") {
    [body, code_line, ..] -> #(
      result.unwrap(int.parse(string.trim(code_line)), -1),
      body,
    )
    _ -> #(-1, out)
  }
}

fn must_read(path: String) -> String {
  case read_file(path) {
    Ok(bits) ->
      case bit_array.to_string(bits) {
        Ok(s) -> s
        Error(_) -> panic as "not utf-8"
      }
    Error(_) -> panic as "missing committed config"
  }
}

fn final_stage(src: String) -> String {
  case string.split(src, "\nFROM ") {
    [] -> ""
    parts ->
      list.last(parts)
      |> result.unwrap("")
  }
}

fn count_needle(hay: String, needle: String) -> Int {
  case string.split(hay, needle) {
    [] -> 0
    parts -> list.length(parts) - 1
  }
}

fn has_command_line(src: String, cmd: String) -> Bool {
  string.split(src, "\n")
  |> list.any(fn(line) {
    let trimmed = string.trim(line)
    !string.starts_with(trimmed, "#") && string.contains(trimmed, cmd)
  })
}

const clone_recipe: String = "git clone --depth 1 --no-checkout \"https://x-access-token:${token}@${host}/${GITHUB_REPOSITORY}\" ."

fn token_clones(body: String) -> Bool {
  string.contains(body, clone_recipe)
  && string.contains(body, "missing job token for git fetch")
  && string.contains(body, "git fetch --depth 1 origin \"${GITHUB_SHA}\"")
}

fn runs_make_check(body: String) -> Bool {
  string.contains(body, "make test")
  || string.contains(body, "make sast")
  || string.contains(body, "make audit")
  || string.contains(body, "make secrets")
  || string.contains(body, "make format")
}

fn jobs_with(jobs: List(#(String, String)), needle: String) -> List(String) {
  list.filter_map(jobs, fn(job) {
    case string.contains(job.1, needle) {
      True -> Ok(job.0)
      False -> Error(Nil)
    }
  })
}

fn must_job(jobs: List(#(String, String)), name: String) -> String {
  case list.find(jobs, fn(job) { job.0 == name }) {
    Ok(job) -> job.1
    Error(_) -> panic as "missing job"
  }
}

fn workflow_jobs(src: String) -> List(#(String, String)) {
  case string.split(src, "\njobs:\n") {
    [_, rest] -> parse_jobs(rest)
    [_, rest, ..] -> parse_jobs(rest)
    _ -> panic as "missing jobs:"
  }
}

fn parse_jobs(jobs_block: String) -> List(#(String, String)) {
  parse_job_lines(string.split(jobs_block, "\n"), "", "", [])
}

fn parse_job_lines(
  lines: List(String),
  current_name: String,
  current_body: String,
  acc: List(#(String, String)),
) -> List(#(String, String)) {
  case lines {
    [] -> list.reverse(push_job(current_name, current_body, acc))
    [line, ..rest] ->
      case job_header_name(line) {
        Ok(name) -> {
          let acc = push_job(current_name, current_body, acc)
          parse_job_lines(rest, name, "", acc)
        }
        Error(_) -> {
          let body = case current_body {
            "" -> line
            _ -> current_body <> "\n" <> line
          }
          parse_job_lines(rest, current_name, body, acc)
        }
      }
  }
}

fn push_job(
  name: String,
  body: String,
  acc: List(#(String, String)),
) -> List(#(String, String)) {
  case name {
    "" -> acc
    _ -> [#(name, body), ..acc]
  }
}

fn job_header_name(line: String) -> Result(String, Nil) {
  case
    string.starts_with(line, "  ")
    && !string.starts_with(line, "    ")
    && string.ends_with(line, ":")
  {
    False -> Error(Nil)
    True -> {
      let name = string.drop_end(string.drop_start(line, 2), 1)
      case name == "" || string.contains(name, " ") {
        True -> Error(Nil)
        False -> Ok(name)
      }
    }
  }
}
