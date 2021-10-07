#!/bin/sh
## change to "bin/bash" when necessary

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 cloudflare_domain.config" >&2
    exit 1
fi

define_default() {
  auth_email=""                                   # The email used to login 'https://dash.cloudflare.com'
  auth_method="token"                             # Set to "global" for Global API Key or "token" for Scoped API Token 
  auth_key=""                                     # Your API Token or Global API Key
  zone_identifier=""                              # Can be found in the "Overview" tab of your domain
  record_name=""                                  # Which record you want to be synced
  proxy=false                                     # Set the proxy to true or false
}

update_record() {
  echo "Executing with config:"
  echo "auth_email=${auth_email}"
  echo "auth_method=${auth_method}"
  echo "auth_key=*********"
  echo "zone_identifier=${zone_identifier}"
  echo "record_name=${record_name}"
  echo "proxy=${proxy}"

  ###########################################
  ## Check and set the proper auth header
  ###########################################
  if [ "${auth_method}" == "global" ]; then
    auth_header="X-Auth-Key:"
  else
    auth_header="Authorization: Bearer"
  fi

  ###########################################
  ## Seek for the A record
  ###########################################

  logger "DDNS Updater: Check Initiated"
  record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name" -H "X-Auth-Email: $auth_email" -H "$auth_header $auth_key" -H "Content-Type: application/json")

  ###########################################
  ## Check if the domain has an A record
  ###########################################
  if [[ $record == *"\"count\":0"* ]]; then
    logger -s "DDNS Updater: Record does not exist, perhaps create one first? (${ip} for ${record_name})"
    return 1
  fi

  ###########################################
  ## Get existing IP
  ###########################################
  old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
  # Compare if they're the same
  if [[ $ip == $old_ip ]]; then
    logger "DDNS Updater: IP ($ip) for ${record_name} has not changed."
    return 0
  fi

  ###########################################
  ## Set the record identifier from result
  ###########################################
  record_identifier=$(echo "$record" | sed -E 's/.*"id":"(\w+)".*/\1/')

  ###########################################
  ## Change the IP@Cloudflare using the API
  ###########################################
  update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                      -H "X-Auth-Email: $auth_email" \
                      -H "$auth_header $auth_key" \
                      -H "Content-Type: application/json" \
                --data "{\"id\":\"$zone_identifier\",\"type\":\"A\",\"proxied\":${proxy},\"name\":\"$record_name\",\"content\":\"$ip\"}")

  ###########################################
  ## Report the status
  ###########################################
  case "$update" in
  *"\"success\":false"*)
    logger -s "DDNS Updater: $ip $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update"
    return 1;;
  *)
    logger "DDNS Updater: $ip $record_name DDNS updated."
    return 0;;
  esac

}

###########################################
## Check if we have a public IP
###########################################
ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com/)

if [ "${ip}" == "" ]; then 
  logger -s "DDNS Updater: No public IP found"
  exit 1
fi

define_default

while read LINE; do
    if [[ $LINE == \#* ]]; then
        continue
    fi

    if [[ -n $LINE ]]; then
        declare "$LINE"
    else
        res=$(update_record)
        echo "DDNS Return code ${res}"
        define_default
    fi
done < "$1"

res=$(update_record)
echo "DDNS Return code ${res}"