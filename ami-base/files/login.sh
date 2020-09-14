#!/bin/bash

set -euo pipefail

source /etc/environment

username=${1}
password=${2}

cookie_file=$(mktemp)
target_cookie_file="${3:-${HOME}/.alpha/gitcookie}"

git_config_file="${4:-${HOME}/.gitconfig}"


mkdir -p $(dirname "${cookie_file}")

rm -rf "${cookie_file}"

git config --file "${git_config_file}" http.https://gerrit.pipeline.alpha-prosoft.com.cookieFile "${target_cookie_file}"
git config --file "${git_config_file}" https.https://gerrit.pipeline.alpha-prosoft.com.cookieFile "${target_cookie_file}"

headers=$(mktemp)
#echo "Storing headers into ${headers}"

curl -s --http1.1 -f --connect-timeout 5 --retry 3 -D "${headers}" -c ${cookie_file} -b ${cookie_file} -L 'https://login.pipeline.alpha-prosoft.com' > $(mktemp)
export location=$(cat "${headers}" | sed 's/\\r//g' | grep -i "location" | head -1 | awk '{print $2}' | sed 's/\/oauth2.*//g')
export client_id=$(cat "${headers}" | sed 's/\\r//g' | grep -i  "location" | head -1 | awk '{print $2}' | sed 's/.*client_id=//g' | sed 's/&.*//g')
export redirect_uri=$(cat "${headers}" | sed 's/\\r//g' | grep -i  "location" | head -1 | awk '{print $2}' | sed 's/.*redirect_uri=//g' | sed 's/&.*//g')
export url_state=$(cat "${headers}" | sed 's/\r//g' | grep -i  "location" | head -1 | awk '{print $2"&"}' | sed 's/.*state=//g' | sed 's/&.*//g')


#echo "Location: $location"
#echo "Client id: $client_id"
#echo "Redirect uri: $redirect_uri"
#echo "State: ${url_state}"

sed -i 's/#HttpOnly_//g' ${cookie_file}

XSRF_TOKEN=$(cat ${cookie_file}  | grep 'XSRF-TOKEN' | awk '{printf $7}')


final_url="${location}/login?client_id=${client_id}&redirect_uri=${redirect_uri}&response_type=code&scope=openid&state=${url_state}"

curl --http1.1 -s -f --connect-timeout 5 --retry 3  -L -c ${cookie_file} -b ${cookie_file}  ''"${final_url}"''\
     -H "referer: ${final_url}" \
     -H 'accept-language: en-US,en;q=0.9,hr;q=0.8'  \
     -H 'csrf-state=""; csrf-state-legacy=""' \
     --data-raw '_csrf='"${XSRF_TOKEN}"'&username='"${username}"'&password='"${password}"'&signInSubmitButton=Sign+in' > /dev/null

result=$(curl -s --http1.1 -f --connect-timeout 5 -L -b ${cookie_file} https://login.pipeline.alpha-prosoft.com)

sed -i 's/#HttpOnly_//g' ${cookie_file}
sed -i 's/login.pipeline.alpha-prosoft.com.*FALSE/pipeline.alpha-prosoft.com\tTRUE/g' ${cookie_file}

chmod 644 "${cookie_file}"

cp ${cookie_file} ${target_cookie_file}

if [[ '{"login" : "success"}' = ${result} ]];then
  echo "Login successful";
else
  echo "Login failed: ${result}"
fi
