#!/bin/bash

# ddns update script for cloudflare
# crontab entry:    */15 * * * * /path/to/cloudflare-ddhs.sh

### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ###
###                                                          ###
###  YOU SHOULD NOT NEED TO CHANGE THIS FUNCTION UNLESS YOU  ###
###          WISH TO CHANGE THE LOGIC OF THE UPDATER!        ###
###                                                          ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ###
###                                                          ###
###  GO TO THE BOTTOM OF THE SCRIPT TO CONFIGURE API BEARER  ###
###                AND ZONES/RECORDS TO UPDATE               ###
###                                                          ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ###

thisip=$(dig @1.1.1.1 ch txt whoami.cloudflare +short | tr -d "[]{}\"\',")
if [ -z "$thisip" ]; then echo "problem getting external ip from cloudflare" && exit; fi

function update {

  parent="$1" && if [ -z "$parent" ]; then
    echo "function called without paramaters" && return 0
  fi

  dnsrec="$2" && if [ -z "$dnsrec" ]; then
    echo "$parent: dns record must be specified (use '.' for domain/zone root)" && return 0;
    elif [ "$dnsrec" == "." ]; then dnsrec="$parent"; else dnsrec="$dnsrec.$parent";
  fi

  bearer="$3" && if [ -z "$bearer" ]; then
    if [ ! -z "$dfbear" ]; then bearer="$dfbear"
    else echo "$dnsrec: no bearer specified and default bearer (\$dfbear) is null" && return 0; fi
  fi

  zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$parent&status=active" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $bearer" | grep -oP '"result":\[\{"id":"[^"]*' | tr -d "[]{}\"\'" | awk -F":" '{print $3}')
  if [ -z "$zoneid" ]; then echo "$parent: could not get zoneid from cloudflare" && return 0; fi

  recdmp=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrec" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $bearer" )

  dnsrid=$(echo $recdmp | grep -oP '"result":\[\{"id":"[^"]*' | tr -d "[]{}\"\'," | awk -F":" '{print $3}')
  if [ -z "$dnsrid" ]; then echo "$dnsrec: could not get dns 'A' record details from cloudflare; record must exist to be updated" && return 0; fi

  record=$(echo $recdmp | grep -oP '"content":"[^"]*' | tr -d "[]{}\"\'," | awk -F":" '{print $2}')
  isprxy=$(echo $recdmp | grep -oP '"proxied":[^"]*' | tr -d "[]{}\"\'," | awk -F":" '{print $2}')

  if [ "$record" != "$thisip" ]; then

    update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrid" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $bearer" \
      --data "{\"type\":\"A\",\"name\":\"$dnsrec\",\"content\":\"$thisip\",\"ttl\":1,\"proxied\":$isprxy}")

    succes=$(echo $update | grep -oP '"success":[^"]*' | tr -d "[]{}\"\'," | awk -F":" '{print $2}')
    if [ "$succes" == true ]; then echo "$dnsrec: dns record updated successfully!"; fi

  fi

}

### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ### ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ### ###
###                                                              ###
###      SET YOUR DEFAULT BEARER TOKEN 'dfbear' AND CALL THE     ###
###    UPDATE FUNCTION FOR EACH ZONE/RECORD YOU NEED TO UPDATE   ###
###                                                              ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ### ###
###                                                              ###
### FORMAT: update domain.tld record [alt_bearer]                ###
###   * record '.' will update domain root                       ###
###   * override default bearer w/ opt. 3rd paramater alt_bearer ###
###                                                              ###
### EXAMPLE:                                                     ###
###                                                              ###
###   dfbear="mydefaultbearertoken"                              ###
###   update    example.org      www                             ###
###   update    example.org      blog                            ###
###   update    example.org      .                               ###
###   update    mybusiness.net   store   alt_bearer_token        ###
###                                                              ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ### ###
### ### ### ### ### ### ### ### ### ### ### #### ### ### ### ### ###


dfbear="mydefaultbearertoken"

update		mylastname.tld		home
update		mylastname.tld		secure
update		mylastname.tld		cloud
update		myothersite.ws		blog	alternate_bearer_token
