# Cross-Platform GRT Script

This script allows you to run Gordon's Reloading Tool on a cross-platform setup using Docker.

## Requirements

Ensure that Docker is installed on your system.

## Getting the GRT Tarball

Download the latest Linux build (NIGHTLY tarball, `*-linux.tar.gz`) from the
official GRT install page:

<https://grtools.de/doku.php?id=grtools:en:doku:install>

Place the downloaded file next to `run-grt.sh` (the script's directory).
A new release ships every few weeks, so re-download periodically to stay
current.

## Configuration

Edit the script and update the following value so that it points to your Linux GRT tarball:

```bash
TARBALL_DEFAULT="GordonsReloadingTool-2021.2040-NIGHTLY-linux.tar.gz"
```

Or override per-run without editing the script:

```bash
GRT_TARBALL=/path/to/GordonsReloadingTool-<version>-linux.tar.gz ./run-grt.sh
```

## Running the Application

After updating the `TARBALL_DEFAULT` value, run the script:

```bash
./run-grt.sh
```

The script will provide you with a URL. Open that URL in your browser to access the application.

Example URL:

```text
http://localhost:6080/vnc.html?host=localhost&port=6080&autoconnect=1&resize=scale
```

## Saving and Loading Files (Host Folder Mount)

GRT runs inside an isolated container, so it cannot see your host filesystem
by default. To make Save/Load dialogs useful, the script bind-mounts a host
folder into the container at `/root/Documents`. Anything you save there in
GRT lands in the corresponding folder on your machine, and any files you
drop into that host folder become visible to GRT.

### Defaults

| Host OS | Host path mounted | Inside container |
|---|---|---|
| macOS | `$HOME/Documents` (e.g. `/Users/<you>/Documents`) | `/root/Documents` |
| Linux | `xdg-user-dir DOCUMENTS` if available, else `$HOME/Documents` | `/root/Documents` |
| WSL2 | same as Linux (the WSL user's `~/Documents`) | `/root/Documents` |

The folder is auto-created if it doesn't exist. On launch the script prints
the active mapping, e.g.:

```text
[+] docs:  /Users/jane/Documents  ->  /root/Documents (inside container)
```

### Using a different folder

Set `GRT_DOCS_DIR` before running the script:

```bash
# macOS — point at iCloud Drive instead
GRT_DOCS_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/GRT" ./run-grt.sh

# Linux — dedicated reloading folder
GRT_DOCS_DIR="$HOME/reloading" ./run-grt.sh

# WSL2 — expose the Windows Documents folder
GRT_DOCS_DIR="/mnt/c/Users/<WindowsUser>/Documents" ./run-grt.sh
```

### Using it inside GRT

In any GRT file dialog (Save load, Open load, export, etc.) navigate to
`/root/Documents`. That path inside the container is the host folder shown
in the table above.

### Notes

- `/root/Documents` is the *only* host path exposed by default. Files saved
  elsewhere inside the container live in the container's data volume
  (`./data` next to the script) — fine for GRT's own prefs/database, but
  not where you want your shared loads.
- The container runs as root, so files created in the mounted folder are
  owned by `root` on the host. On macOS Docker Desktop this is masked by
  the VM; on native Linux you may want to `chown` afterward.

## Screenshots

Once the application is running, you should see something similar to the following:

<img width="1906" height="943" alt="GRT running in browser" src="https://github.com/user-attachments/assets/0277cfad-d3e0-4ca5-8ef3-d0772cb1661c" />

<img width="1914" height="965" alt="GRT application interface" src="https://github.com/user-attachments/assets/59bfa4b2-5855-4c17-b315-2de163882f41" />
