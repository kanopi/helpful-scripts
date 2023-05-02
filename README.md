# Helpful Scripts

## Collect Logs

The following script pulls logs from a Pantheon Site instance and uses GoAccess to analyze the traffic.

### Requirements

- Access to a Pantheon Site
- Docker to run GoAccess

### Usage

Basic Usage

```shell
SITE_UUID=xxxxxxxx-yyyy-zzzz-aaaa-bbbbbbbbbbbb bash <(curl -fsSL https://raw.githubusercontent.com/kanopi/helpful-scripts/main/collect-logs.sh)
```

### Configurable Variables

The following variables can be used for prefixing the 

Variable | Required | Default | Details
---------|----------|---------|---------
ENV_FILE | | [[HOME]]/.collectlogs | Environment file to store constant variables to
DEBUG | | | Debug the script piece by piece. When set to 1 will output verbose logs from all items.
SITE_UUID | X | | Pantheon Site UUID. This can be found in the URL to the dashboard
SITE_ENV | | live | Environment to pull logs from
GEOIP_KEY | | | Key from MaxMind to Download the GeoLite2 City database
GEOIP_FILE_LOCATION | | [[ BASEDIR ]]/GeoLite2-City.mmdb | Location of the GeoIP Database
BASEDIR | X | (Current Directory) | Location where reports and logs can be downloaded to
DATA_LOCATION | X | sites/[[ SITE_UUID ]]/[[ SITE_ENV ]] | Location where current project is stored within the base directory
LOG_DIRECTORY | X | logs | Directory in the DATA_LOCATION where the logs are stored
REPORT_DIRECTORY | X | reports | Directory in the DATA_LOCATION where the reports are stored
REPORT_FILE | X | [[ SITE_UUID ]]-[[ SITE_ENV ]]-[[ DATE/TIME ]].html | Name of the file to save the report as
SSH_KEY |  |  | SSH Key to use for connection.
SSH_OPTIONS | | ssh -p 2222 -o StrictHostKeyChecking=no | SSH Options to use for rsync connection. When SSH_KEY is present does not utilize config file
GOACCESS_CONFIG_FILE | | ~/.goaccessrc | GoAccess Location File. If not found one is downloaded from the GoAccess Repo
