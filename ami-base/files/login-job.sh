#!/bin/bash

set -euxo pipefail

username="${ServiceAlias}"
password=$(aws secretsmanager get-secret-value \
            --query "SecretString" --output text \
            --secret-id "/${EnvironmentNameLower}/${username}/password")

. /etc/environment
/opt/login.sh "${username}" "${password}" \
          "/home/${Username}/.gitcookie" \
	  "/etc/traefik/config/login.toml" \
	  "false" \
          "/home/${Username}/.gitconfig"  \
	  $(mktemp)

