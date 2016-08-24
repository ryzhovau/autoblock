# Autoblock

This is a bash script to filter web server logs and ban some IPs which is consumed too much traffic or done too much hits. By default, IPs are banned for one day.

## Requirements

* [goaccess](https://github.com/allinurl/goaccess) to parse logs,
* [ferm](https://github.com/MaxKellermann/ferm) or other firewall to apply changes,
* cron. To do it periodically.

## Installation

* Install dependencies,
* Download script to `/usr/local/bin` and make it executable,
* Edit script for your needs,
* Make cron job to run it once per hour.
