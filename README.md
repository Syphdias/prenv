# Project Environments – prenv
This project provides [zsh] functions to activate a generic project environment
based on configurations in a yaml file.

- Documentation (and FAQ – if any) can found in this README.
- Feel free to file issues to report bugs, ask questions, or request features.
- Feel free to open a pull request.

## Requirements
To parse the configuration yaml, [go-yq] is being used. Do not confuse it with
other implementations of `yq` which are based around `jq`.

## Installation
There is currently no classic installation/package. Clone the repo or download
`prenv.zsh` and source it in your `.zshrc`.

```zsh
source path/to/prenv.zsh
```

If you are using [Powerlevel10k] you can also source `prenv-p10k-segment.zsh`
and source it in your `.zshrc` as well. You then can add the segment `prenv` to
`POWERLEVEL9K_LEFT_PROMPT_ELEMENTS` or `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS`.

## Usage
In the configuration file you can define environment variables to be set and
commands to be run, when you activate the environment.
[Sourcing the prenv file](#Installation) will provide the function `prenv` to
list, activate, and deactivate the project environment.

You can have multiple projects active. By default activating a new project will
deactivate the old one. Having multiple active projects can lead to confusion if
you have overlapping environment definitions!

### Writing config
Every project is a hash/dictionary. Each project has `env` and `hooks`.

In `env` you can define key value pairs that will be set with `export` on
activation of the project (`prenv on PROCJET`) and will be unset if you
deactivate the project (`prenv off PROCJET`).

In `hooks` you can define commands to be run on certain `prenv COMMAND`s: `on`, `off`, `clear`. For
example you can define `PROJECT.hooks.on` to run commands that will be run on
project activation.

#### Example `~/.config/prenv.yaml`
```yaml
private:
  env:
    AWS_PROFILE: private
    KUBECONFIG: ~/.config/kubeconfig/private
    variable2: "$foobar"
    variable3: '$foobar'
  hooks:
    on: |   # Run some Commands on activation
      echo Activated private project
      cd to/some/path
    off: |  # Run Commands on deactivating project
      echo Deactivated private project
    clear: "echo Clearing commands"

customer1:
  env:
    AWS_PROFILE: customer1
    KUBECONFIG: ~/.config/kubeconfig/customer1"
  hooks:    # Run script/program on activation
    on: "/usr/bin/xrandr"

customer2:
  env:
    AWS_PROFILE: customer2
    KUBECONFIG: ~/.config/kubeconfig/customer2
    HISTFILE: ~/.config/zsh/history/customer2
```

### Commands
There are a few subcommds to `prenv` to use it in the form of `prenv COMMAND`
with the following COMMANDS:
- `list` to list all projects
- `on [PROJECT]` to activate a project. This means to set all environement
  variables and trigger the on hook. To ensure a clean environement the current
  project will be deactivated (see `off` command).If you provide `-p` the
  current project will not be deactivated — note that this might lead to
  unexpected behaviour. Omitting the project will reactivate the current
  project(s).
- `off [PROJECT]` to deactivate a project. This unsets all environment variables
  of the activated project(s) and trigger the off hook(s). Omitting the project
  will deactivate the active projects.
- `clear` to unset any envrionment variables mentioned in the configuration and
  trigger the clear hooks.
- `show` to show curretly active project(s)
- `help` to show all options of subcommands
   
## Know Issues
- Possibly this README and help command. Please give feedback!

## Feature Ideas
- multi configurations: enable using multiple files
    - files in fixed config dir?
    - include statement for more files?
- zsh completion
- AUR if anybody wants it
    - requires versioning, because I am not a fan of `-git` packages


[zsh]: https://github.com/zsh-users/zsh
[go-yq]: https://github.com/mikefarah/yq
[Powerlevel10k]: https://github.com/romkatv/powerlevel10k
