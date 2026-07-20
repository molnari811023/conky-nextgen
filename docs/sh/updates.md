# updates.sh

## Purpose
Checks for Arch Linux package updates (repo + AUR). Writes counts to `tmp/updates.txt`.

## Dependencies
- `curl`, `jq`, `pacman`, `vercmp`, `checkupdates`

## Usage
```bash
./sh/updates.sh
```

## Output
Writes two numbers to `tmp/updates.txt`:
```
<repo_count> <aur_count>
```

Read by `lua/hardware/core.lua` functions `conky_updates_repo()` and `conky_updates_aur()`.

## How it works
- Uses `checkupdates` for repo package count
- Queries AUR RPC API for installed AUR package versions
- Compares with `vercmp` to detect outdated AUR packages
