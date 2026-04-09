# CoStuBs Nix Environment ❄️

Welcome to the fully reproducible, cross-platform development environment for
the **Betriebssysteme 1 (BS1)** course at BTU-Cottbus!

This repository provides a modern **Nix Flake Template** for building the
CoStuBs Operating System. Whether you are on Ubuntu, Arch Linux, an Intel Mac,
or an M-series Apple Silicon Mac, this setup guarantees you have the exact same
compilers, tools, and emulator versions—without installing anything globally to
your host operating system.

---

## 🚀 1. Prerequisites

You only need one thing installed on your machine: **The Nix Package Manager**.

If you don't have Nix installed, open your terminal and run the official multi-user installer:
```bash
sh <(curl -L [https://nixos.org/nix/install](https://nixos.org/nix/install)) --daemon
```
*(Note: Nix Flakes must be enabled. If you are on a fresh install, you may need
to add `experimental-features = nix-command flakes` to your `~/.config/nix/nix.conf`).*

---

## 🛠️ 2. Getting Started (Initialization)

Because this repository is a **Nix Template**, you don't need to manually
clone it. You can instantly generate a fresh, ready-to-code project folder.

1. Create a new directory for your assignment and enter it:
   ```bash
   mkdir my-bs1-os
   cd my-bs1-os
   ```
2. Initialize the template:
   ```bash
   nix flake init -t github:leonieziechmann/costubs-nixified
   ```
3. Initialize Git (Nix requires files to be tracked by Git to see them!):
   ```bash
   git init
   git add .
   ```

---

## 💻 3. Developing the OS (`nix develop`)

When it's time to actually write code and test your changes, you will use the
development shell.

```bash
nix develop
```

**How it works:**
This command drops you into an isolated, secure shell. It temporarily loads all
the required dependencies directly into your `$PATH`
(like `gcc-12`, `clang`, `make`, `nasm`, and a custom-compiled `bochs-2.7`).
- If you are on Linux, it uses the native multilib compiler. 
- If you are on a Mac, it seamlessly injects an `i686-elf` cross-compiler so the standard Makefile works flawlessly.

Once inside the shell, you navigate and compile exactly as if you were on a native Linux machine:
```bash
cd bin/
make bootdisk    # Compiles your OS code into an ISO
make bochs-run   # Launches the Bochs emulator
make clean       # Cleans up build artifacts
```
Type `exit` when you are done to leave the environment and return your terminal to normal.

---

## 🚀 4. Quick Execution & Building

If you don't want to drop into the development shell, Nix provides two powerful shortcuts:

### The Quick Run (`nix run`)
Want to instantly compile the OS and boot it in Bochs without leaving artifacts in your folder? 
```bash
nix run
```
*This securely builds `costubs.iso` in the Nix sandbox, creates a temporary
directory, copies the configuration, and launches Bochs. When you close Bochs,
all temporary log files instantly delete themselves, keeping your workspace
perfectly clean!*

### The Build Target (`nix build`)
If you just want to generate the compiled `.iso` file to use in your own
virtual machine (like QEMU or VMware):
```bash
nix build
```
*Nix will build the OS in total isolation and place a `result/` symlink in your
current directory containing `costubs.iso`.*

---

## ✨ Pro-Tip: Supercharge your workflow with `direnv`

Tired of typing `nix develop` every time you open your terminal? You can 
automate it using **`direnv`**.

**The Magic:** With this setup, every time you `cd` into your project folder,
your Nix environment will load *automatically* in the background, and unload
when you leave the folder. It makes Nix feel completely invisible!

### Quick Setup
Run this in your terminal to download `direnv` and configure your project folder:

```bash
# 1. Install direnv
curl -sfL https://direnv.net/install.sh | bash

# 2. Automatically add the hook to your Bash or Zsh config (if not already there)
CONF_FILE=~/."$(basename $SHELL)"rc
grep -q "direnv hook" "$CONF_FILE" || echo 'eval "$(direnv hook $(basename $SHELL))"' >> "$CONF_FILE"

# 3. Setup the project and allow it
echo "use flake" > .envrc && direnv allow
```

**The Magic:** Now, every time you `cd` into your project folder, your Nix
environment will load *automatically* in the background, and unload when you
leave the folder. It makes Nix feel completely invisible!
