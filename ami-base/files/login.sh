#!/bin/bash

set -euxo pipefail

username=$1
password=$2

cookie_file="${3:-${HOME}/alpha/gitcookie}"
config_file="${4:-${HOME}/alpha/config.toml}"
generate_traefik_config="${5:-"true"}"
git_config_file="${6:-${HOME}/.gitconfig}"
traefik_file="${7:-${HOME}/alpha/traefik.toml}"


mkdir -p $(dirname "${cookie_file}")
mkdir -p $(dirname "${config_file}")
mkdir -p $(dirname "${traefik_file}")

rm -rf "${cookie_file}"

git config --file "${git_config_file}" http.https://scm.pipeline.alpha-prosoft.com.cookieFile "${cookie_file}"
git config --file "${git_config_file}" https.https://scm.pipeline.alpha-prosoft.com.cookieFile "${cookie_file}"


headers=$(mktemp)
echo "Storing headers into ${headers}"

curl --http1.1 -f --connect-timeout 5 --retry 3 -D "${headers}" -c ${cookie_file} -b ${cookie_file} -L 'https://login.pipeline.alpha-prosoft.com' > $(mktemp)
export location=$(cat "${headers}" | sed 's/\\r//g' | grep -i "location" | head -1 | awk '{print $2}' | sed 's/\/oauth2.*//g')
export client_id=$(cat "${headers}" | sed 's/\\r//g' | grep -i  "location" | head -1 | awk '{print $2}' | sed 's/.*client_id=//g' | sed 's/&.*//g')
export redirect_uri=$(cat "${headers}" | sed 's/\\r//g' | grep -i  "location" | head -1 | awk '{print $2}' | sed 's/.*redirect_uri=//g' | sed 's/&.*//g')
export url_state=$(cat "${headers}" | sed 's/\r//g' | grep -i  "location" | head -1 | awk '{print $2"&"}' | sed 's/.*state=//g' | sed 's/&.*//g')


echo "Location: $location"
echo "Client id: $client_id"
echo "Redirect uri: $redirect_uri"
echo "State: ${url_state}"

sed -i 's/#HttpOnly_//g' ${cookie_file}

cat ${cookie_file}

XSRF_TOKEN=$(cat ${cookie_file}  | grep 'XSRF-TOKEN' | awk '{printf $7}')


final_url="${location}/login?client_id=${client_id}&redirect_uri=${redirect_uri}&response_type=code&scope=openid&state=${url_state}"

curl --http1.1 -v -f --connect-timeout 5 --retry 3  -L -c ${cookie_file} -b ${cookie_file}  ''"${final_url}"''\
     -H "referer: ${final_url}" \
     -H 'accept-language: en-US,en;q=0.9,hr;q=0.8'  \
     -H 'csrf-state=""; csrf-state-legacy=""' \
     --data-raw '_csrf='"${XSRF_TOKEN}"'&username='"${username}"'&password='"${password}"'&signInSubmitButton=Sign+in'

result=$(curl --http1.1 -f --connect-timeout 5 -L -b ${cookie_file} https://login.pipeline.alpha-prosoft.com)

sed -i 's/#HttpOnly_//g' ${cookie_file}

if [[ "${generate_traefik_config}" == "true" ]]; then
  cat <<EOF > ${traefik_file}
  defaultEntryPoints = ["http"]

  [entryPoints]
    [entryPoints.local-private]
      address = "127.0.0.1:18999"
    [entryPoints.local.forwardedHeaders]
      insecure = true



  [providers]
    [providers.file]
      filename = "$HOME/alpha/config.toml"
      watch = true

  [log]
    filePath = "$HOME/alpha/traefik.log"
  [accessLog]

  [ping]
    entryPoint = "http"
EOF
  chmod 644 "${traefik_file}"
fi


cat <<EOF > ${config_file}
[http.middlewares]
  [http.middlewares.local-private.headers]
    [http.middlewares.local-private.headers.customRequestHeaders]
      Host = "scm.pipeline.alpha-prosoft.com"
      Cookie = "AWSELBAuthSessionCookie-0=$(cat ${cookie_file}  | grep "AWSELBAuthSessionCookie-0" | awk '{printf $7}'); AWSELBAuthSessionCookie-1=$(cat .gitcookie  | grep "AWSELBAuthSessionCookie-1" | awk '{printf $7}')"

[http]
    [http.routers]
       [http.routers.local-private]
          rule = "PathPrefix(\`/\`)"
          service = "local-private"
          entryPoints = ["local-private"]
          middlewares = ["local-private"]

    [http.services]
          [http.services.local-private.loadbalancer]
            [[http.services.local-private.loadbalancer.servers]]
              url = "https://scm.pipeline.alpha-prosoft.com"

EOF

chmod 644 "${cookie_file}"
chmod 644 "${config_file}"

if [[ '{"login" : "success"}' = ${result} ]];then
  echo "Login successful";
else
  echo "Login failed: ${result}"
fi

