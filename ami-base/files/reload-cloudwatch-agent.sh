#!/bin/bash

# shellcheck disable=SC1091
source /etc/environment

set -eu

files="$(mktemp)"
new_config="$(mktemp)"
echo "New config file ${new_config}"
jsonFile=/etc/amazon-cloudwatch-agent.json
targetFile=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

while read -r dir; do
  if [[ -d "${dir}" ]]; then
    find "${dir}" -name "*log" -print >>"${files}"
  fi
done </opt/dir_list.txt

file_list=$(mktemp)

sort "${files}" | uniq >"${file_list}"

if diff "${file_list}" /opt/file_list.txt >/dev/null; then
  echo "No change in config"
else
  echo "Difference detected"
  echo "Found files"
  cat /opt/file_list.txt

  cp "${jsonFile}" "${new_config}"
  while read -r p; do
    echo "Adding config for file $p"
    temp_new_config=$(mktemp)
    # shellcheck disable=SC2154
    jq '.logs.logs_collected.files.collect_list +=
	  [{
	    "file_path": "'"$p"'",
	    "log_group_name": "'"${ServiceName}"'",
	    "log_stream_name": "{instance_id}-'"$p"'",
	    "timezone": "UTC"
	    }]' "${new_config}" >"${temp_new_config}"
    mv "${temp_new_config}" "${new_config}"
  done <"${file_list}"

  rm -rf "${targetFile}"
  echo "####### FINAL CONFIG #########"
  cat "${new_config}"
  echo "##############################"
  amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c "file:${new_config}"
  /bin/systemctl stop amazon-cloudwatch-agent.service
  /bin/systemctl restart amazon-cloudwatch-agent.service

  echo " ####### FINAL TOML #########"
  cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.toml
  echo "##############################"
  cp "${file_list}" /opt/file_list.txt

fi

rm -f "${file_list}" "${files}"
