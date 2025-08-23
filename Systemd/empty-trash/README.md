# Empty Trash Systemd Units

[![MIT License](https://img.shields.io/github/license/xanderboy2001/Scripts.svg?style=for-the-badge)](../../LICENSE)

## About

This folder contains systemd unit and timer files to automatically empty trash for all users on Linux. It only deletes files that were trashed at least 7 days ago.

Included files:

- `empty-trash.service` - Service to empty trash.
- `empty-trash.timer` - Timer to run the service daily.

## Prerequisites

This services uses `trash-cli` to empty the trash. If it is not installed, the service will simply do nothing. You can find the project page [here](https://github.com/andreafrancia/trash-cli).

## Installation

Clone the repository (if you haven’t already) anywhere you like:

```bash
git clone https://github.com/xanderboy2001/Scripts.git
```

Create symlinks for the systemd unit files:

```bash
sudo ln -s /path/to/files/empty-trash.service /etc/systemd/system/empty-trash.service
sudo ln -s /path/to/files/empty-trash.timer /etc/systemd/system/empty-trash.timer
```

Reload systemd to recognize the new units:

```bash
sudo systemctl daemon-reload
```

Enable and start the timer:

```bash
sudo systemctl enable --now empty-trash.timer
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

- The service automatically empties trash files older than 7 days for all users. It runs `trash-empty --all-users -f 7` as root.
- The timer ensures the service runs daily. If the computer is off at the scheduled time, it will run the next time the system boots.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Fork the repo and submit pull requests for improvements or new systemd units.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## License

Distributed under the MIT License. See [LICENSE](../../LICENSE) for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>
