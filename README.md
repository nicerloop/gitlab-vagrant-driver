# gitlab-vagrant-driver

Custom GitLab Runner driver that provisions CI jobs in [Vagrant](https://developer.hashicorp.com/vagrant) VMs (currently Windows and macOS guest boxes) using the runner [custom executor](https://docs.gitlab.com/runner/executors/custom/) lifecycle.

## Installation

On macOS, you can use [homebrew](https://brew.sh) with a [custom gitlab-vagrant-driver tap](https://github.com/nicerloop/homebrew-gitlab-vagrant-driver):

```sh
tap nicerloop/gitlab-vagrant-driver
brew install gitlab-vagrant-driver
```

## Runner registration configuration

When registering a GitLab Runner for this driver, choose the `custom` executor, install the driver script in a directory on `PATH`, then configure the custom stage commands to call `gitlab-vagrant-driver`.

Example install:

```sh
install -m 0755 ./bin/gitlab-vagrant-driver /usr/local/bin/gitlab-vagrant-driver
```

Example `config.toml` section for a registered runner:

```toml
[[runners]]
  name = "vagrant-custom-runner"
  executor = "custom"

  [runners.custom]
    config_exec = "gitlab-vagrant-driver"
    config_args = ["config", "box=bento/windows-11", "provider=virtualbox", "template=share/templates/Vagrantfile.vbox.win.erb"]
    prepare_exec = "gitlab-vagrant-driver"
    prepare_args = ["prepare"]
    run_exec = "gitlab-vagrant-driver"
    run_args = ["run"]
    cleanup_exec = "gitlab-vagrant-driver"
    cleanup_args = ["cleanup"]
```

Ensure the runner service account can resolve `gitlab-vagrant-driver` from `PATH`.

## What it does

The driver script is at `bin/gitlab-vagrant-driver` and supports four stages:

- `config`: returns driver + job environment metadata in JSON
- `prepare`: creates a `Vagrantfile` and boots the VM
- `run`: uploads and executes the job script in the guest
- `cleanup`: destroys the VM

## Driver entrypoint

```sh
bin/gitlab-vagrant-driver <stage> [args...]
```

## Stage usage

### 1) config

```sh
bin/gitlab-vagrant-driver config box=bento/windows-11 provider=virtualbox template=share/templates/Vagrantfile.vbox.win.erb
```

Accepted args:

- `box=<box-name[:version]>`
- `provider=<vagrant-provider>`
- `template=<path-to-vagrantfile-template>`

Notes:

- `CUSTOM_ENV_JOB_IMAGE` overrides the `box` value when present.
- Supported guests are inferred from box name:
  - names containing `windows` use `powershell` + `winrm`
  - names containing `macos` use `sh` + `ssh`

### 2) prepare

```sh
bin/gitlab-vagrant-driver prepare
```

Runs:

- `vagrant init ... --force`
- `vagrant up ...`

### 3) run

```sh
bin/gitlab-vagrant-driver run ./job_script.ps1 "optional description"
```

Behavior:

- uploads script to guest temp dir
- executes through the selected communicator (`winrm` or `ssh`)

### 4) cleanup

```sh
bin/gitlab-vagrant-driver cleanup
```

Destroys VM with force.

## Debugging

Enable shell tracing and emit `driver.env` during `config`:

```sh
export VAGRANT_DRIVER_DEBUG=1
```

## Templates

Built-in templates:

- `share/templates/Vagrantfile.erb`
- `share/templates/Vagrantfile.tart.mac.erb`
- `share/templates/Vagrantfile.vbox.win.erb`
- `share/templates/gitlab-runner-config-template.toml`

## Local integration test helpers

Under `test/`:

- `start.sh`: boots local GitLab, registers runner, creates sample project/pipeline
- `stop.sh`: tears down local test environment
- `build-bento.sh`: builds and adds local `bento/windows-11` box

Run from repo root:

```sh
cd test
./start.sh
# ... validate pipeline execution ...
./stop.sh
```
