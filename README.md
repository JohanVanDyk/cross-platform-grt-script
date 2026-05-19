# Cross-Platform GRT Script

This script allows you to run Gordon's Reloading Tool on a cross-platform setup using Docker.

## Requirements

Ensure that Docker is installed on your system.

## Configuration

Edit the script and update the following value so that it points to your Linux GRT tarball:

```bash
TARBALL_DEFAULT="GordonsReloadingTool-2021.2040-NIGHTLY-linux.tar.gz"
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

## Screenshots

Once the application is running, you should see something similar to the following:

<img width="1906" height="943" alt="GRT running in browser" src="https://github.com/user-attachments/assets/0277cfad-d3e0-4ca5-8ef3-d0772cb1661c" />

<img width="1914" height="965" alt="GRT application interface" src="https://github.com/user-attachments/assets/59bfa4b2-5855-4c17-b315-2de163882f41" />
