#!/bin/bash

# Extracts all Members with associated Applications and PackageKeys
# Output in JSON

# (c) 2023 TIBCO Software Inc.
#The following information is confidential information of TIBCO Software Inc. Use, duplication, transmission, or republication for any purpose #without the prior written consent of TIBCO is expressly prohibited.

#This document (including, without limitation, any product roadmap or statement of direction data) illustrates the planned testing, release and availability dates for TIBCO products and services. This document is provided for informational purposes only and its contents are subject to change without notice. TIBCO makes no warranties, express or implied, in or relating to this document or any information in it, including, without limitation, that this document, or any information in it, is error-free or meets any conditions of merchantability or fitness for a particular purpose. This document may not be reproduced or transmitted in any form or by any means without our prior written permission.
#The material provided is for informational purposes only, and should not be relied on in making a purchasing decision. The information is not a commitment, promise or legal obligation to deliver any material, code, or functionality. The development, release, and timing of any features or functionality described for our products remain at our sole discretion.
#In this document TIBCO or its representatives may make forward-looking statements regarding future events, TIBCO's future results or our future financial performance. These statements are based on management's current expectations. Although we believe that the expectations reflected in the forward-looking statements contained in this document are reasonable, these expectations or any of the forward-looking statements could prove to be incorrect and actual results or financial performance could differ materially from those stated herein. TIBCO does not undertake to update any forward-looking statement that may be made from time to time or on its behalf.

# 20231109 - MMussett - First version.


#
# Debug
#set -x
# Script name
NAME="$(basename $0)"
# Mashery API base
MASHERY_API_BASE="https://api.mashery.com"

MEMBERS_FIELDS="id,username,firstName,lastName,email,areaStatus"
#MEMBERS_FIELDS="id,username,firstName,lastName,email,areaStatus,partner_identifier"

MEMBERAPPLICATION_FIELDS="id,name,packageKeys"

# Sleep between requests
THROTTLE=1.25
# Request retries
RETRIES=3
# Maximum number of records
LIMIT=1000

# Output usage information
function usage() {
	echo "usage: $NAME -u username -p password -k apiKey -s apiSecret -a areaUuid"
	echo " Extract all members with their applications and package keys."
	echo "    $NAME -u dev@tibco.com -p mypwd123 -k 5cwt42e494bb4h7fkxsh6xh6 -s Sq4UjgLZ2U -a 12b2de7a-c456-4cc0-893d-4bbf3123be2b > extract.json"
	exit 1
}

# Check dependencies are installed
function getDependencies() {
	for dep in jq curl awk; do
		if ! [ -x "$(command -v $dep)" ]; then
			echo -n "$NAME: $dep is not installed." >&2
			if [[ "$dep" == "jq" ]]; then
			 echo " See https://stedolan.github.io/jq/." >&2
		 	else
			 echo >&2
		 	fi
		exit 2
		fi
	done
}

# Get API access token
function getToken() {
	local area=$1
	local token=""
	sleep $THROTTLE # throttle
	local output=($(curl -w "\n%{http_code}\n" -s -X POST $MASHERY_API_BASE/v3/token -H "Authorization: Basic $(echo -n $KEY:$SECRET | base64)" -H "Content-Type: application/x-www-form-urlencoded" -d "grant_type=password&username=$USERNAME&password=$PASSWORD&scope=$area"))

	local status=${output[1]}

	if [[ "$VERBOSE" == "true" ]]; then
		echo "API Token API Status Code = "$status >&2
	fi

	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get token for area $1, returned status $status, response ${output[0]} >&2
		exit 3
	else
		if [[ "$VERBOSE" == "true" ]]; then
			echo "POST $MASHERY_API_BASE/v3/token Response = "$output >&2
		fi

		token=$(echo ${output[0]} | jq -r '.access_token')
	fi
	echo $token
}

# Set options
function setopts() {

	# Get command line options
	while getopts :a:b:d:k:p:s:u:v: opt; do
	  case ${opt} in
			a ) # area
				AREA="$OPTARG"
	      ;;
			k ) # key
				KEY="$OPTARG"
	      ;;
			p ) # password
				PASSWORD="$OPTARG"
	      ;;
			s ) # secret
				SECRET="$OPTARG"
	      ;;
			u ) # username
				USERNAME="$OPTARG"
	      ;;
		  	v ) # verbose
				VERBOSE="true"
		  ;;
	    \? ) usage
	      ;;
	  esac
	done
	shift $((OPTIND-1))

	# Check arguments
	if [[ "$USERNAME" == "" || "$PASSWORD" == "" || "$KEY" == "" || "$SECRET" == "" || "$AREA" == "" ]]; then
		usage
	fi

}

# Get all members id
function getAllMembers() {
	local token=$1
	local status=0
	local retry=1
	sleep $THROTTLE

	
	while [ $retry -le $RETRIES ]; do
		output=$(curl -w "\n%{http_code}\n" -s -H "Authorization: Bearer $token" "$MASHERY_API_BASE/v3/rest/members?fields=id&limit=$LIMIT")
		status=$(echo "$output" | tail -1)
		content=$(echo "$output" | head -1)

		if [[ $status -eq 200 ]]; then
			break
		fi

		if [[ $status -eq 404 ]]; then
			echo $NAME: failed to get all members with token $token, returned status $status, content $content >&2
			exit 4
		fi

		retry=$(( $retry + 1 ))
		sleep $(( 2 * $retry )) # throttle
		token=$(getToken $AREA)
	done

	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get all members with token $token, returned status $status, content $content >&2
		exit 4
	fi


	if [[ "$VERBOSE" == "true" ]]; then
		echo "POST $MASHERY_API_BASE/v3/rest/members Response = "$output >&2
	fi
	
	echo ${content}
	#endpoints=$(echo "$content" | jq --arg service "$service" '.[] | select( .id | contains($service))')
	
	
	
	# Tab separated values, sort by API definition name then endpoint name
	#echo $endpoints | jq -r '. | .name as $apiName | .id as $apiId | (.endpoints[] | { $apiName, $apiId, name, id, requestPathAlias, outboundRequestTargetPath, publicDomains, systemDomains,  inboundSslRequired, outboundTransportProtocol, allowMissingApiKey, systemDomainAuthentication}) |  .apiId + ","+ .id + "," + .apiName + "," + .name + "," + (.inboundSslRequired|tostring) + "://" + (.publicDomains|tostring) + .requestPathAlias + ","  + (.outboundTransportProtocol|tostring) + "://" + (.systemDomains|tostring) + .outboundRequestTargetPath + "," + (.inboundSslRequired|tostring) + "," + (.outboundTransportProtocol|tostring) + "," + (.allowMissingApiKey|tostring) + "," + (.systemDomainAuthentication.type|tostring)' | awk 'BEGIN {FS=OFS=","}; function subarray(c) {gsub("false","http",$c) gsub("true","https",$c) gsub("\\[\\{\\\"address\\\":\\\"","",$c) gsub("\\\"\\}\\]","",$c) gsub("\\[\\]"," ",$c) gsub("\\\"\\},\\{\\\"address\\\":\\\""," ",$c)} {subarray(5) subarray(6)} 1' | awk 'BEGIN {FS=OFS=","}; function inssl(c) {gsub("false","NO",$c) gsub("true","YES",$c)} {inssl(7)} 1' | awk 'BEGIN {FS=OFS=","}; function outssl(c) {gsub("https","YES",$c) gsub("http","NO",$c)} {outssl(8)} 1' | awk 'BEGIN {FS=OFS=","}; function noapikey(c) {gsub("true","YES",$c) gsub("false","NO",$c)} {noapikey(9)} 1'| awk 'BEGIN {FS=OFS=","}; function sda(c) {gsub("null","NO",$c) gsub("httpBasic","YES (HTTP-BA)",$c) gsub("clientSslCert","YES (SSL-CERT)",$c)} {sda(10)} 1'| sort -k3,3 -k4,4

}

# Get all members id
function getAllMembers() {
	local token=$1
	local status=0
	local retry=1
	sleep $THROTTLE

	
	while [ $retry -le $RETRIES ]; do
		output=$(curl -w "\n%{http_code}\n" -s -H "Authorization: Bearer $token" "$MASHERY_API_BASE/v3/rest/members?fields=id&limit=$LIMIT")
		status=$(echo "$output" | tail -1)
		content=$(echo "$output" | head -1)

		if [[ $status -eq 200 ]]; then
			break
		fi

		if [[ $status -eq 404 ]]; then
			echo $NAME: failed to get all members with token $token, returned status $status, content $content >&2
			exit 4
		fi

		retry=$(( $retry + 1 ))
		sleep $(( 2 * $retry )) # throttle
		token=$(getToken $AREA)
	done

	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get all members with token $token, returned status $status, content $content >&2
		exit 4
	fi


	if [[ "$VERBOSE" == "true" ]]; then
		echo "POST $MASHERY_API_BASE/v3/rest/members Response = "$output >&2
	fi
	
	echo ${content}
	#endpoints=$(echo "$content" | jq --arg service "$service" '.[] | select( .id | contains($service))')
	
	
	
	# Tab separated values, sort by API definition name then endpoint name
	#echo $endpoints | jq -r '. | .name as $apiName | .id as $apiId | (.endpoints[] | { $apiName, $apiId, name, id, requestPathAlias, outboundRequestTargetPath, publicDomains, systemDomains,  inboundSslRequired, outboundTransportProtocol, allowMissingApiKey, systemDomainAuthentication}) |  .apiId + ","+ .id + "," + .apiName + "," + .name + "," + (.inboundSslRequired|tostring) + "://" + (.publicDomains|tostring) + .requestPathAlias + ","  + (.outboundTransportProtocol|tostring) + "://" + (.systemDomains|tostring) + .outboundRequestTargetPath + "," + (.inboundSslRequired|tostring) + "," + (.outboundTransportProtocol|tostring) + "," + (.allowMissingApiKey|tostring) + "," + (.systemDomainAuthentication.type|tostring)' | awk 'BEGIN {FS=OFS=","}; function subarray(c) {gsub("false","http",$c) gsub("true","https",$c) gsub("\\[\\{\\\"address\\\":\\\"","",$c) gsub("\\\"\\}\\]","",$c) gsub("\\[\\]"," ",$c) gsub("\\\"\\},\\{\\\"address\\\":\\\""," ",$c)} {subarray(5) subarray(6)} 1' | awk 'BEGIN {FS=OFS=","}; function inssl(c) {gsub("false","NO",$c) gsub("true","YES",$c)} {inssl(7)} 1' | awk 'BEGIN {FS=OFS=","}; function outssl(c) {gsub("https","YES",$c) gsub("http","NO",$c)} {outssl(8)} 1' | awk 'BEGIN {FS=OFS=","}; function noapikey(c) {gsub("true","YES",$c) gsub("false","NO",$c)} {noapikey(9)} 1'| awk 'BEGIN {FS=OFS=","}; function sda(c) {gsub("null","NO",$c) gsub("httpBasic","YES (HTTP-BA)",$c) gsub("clientSslCert","YES (SSL-CERT)",$c)} {sda(10)} 1'| sort -k3,3 -k4,4

}

# Get a member using id
function getMember() {
	local token=$1
	local memberId=$2
	local status=0
	local retry=1
	sleep $THROTTLE

	
	while [ $retry -le $RETRIES ]; do
		output=$(curl -w "\n%{http_code}\n" -s -H "Authorization: Bearer $token" "$MASHERY_API_BASE/v3/rest/members/$memberId?fields=$MEMBERS_FIELDS&limit=$LIMIT")
		status=$(echo "$output" | tail -1)
		content=$(echo "$output" | head -1)

		if [[ $status -eq 200 ]]; then
			break
		fi

		if [[ $status -eq 404 ]]; then
			echo $NAME: failed to get all members with token $token, returned status $status, content $content >&2
			exit 4
		fi

		retry=$(( $retry + 1 ))
		sleep $(( 2 * $retry )) # throttle
		token=$(getToken $AREA)
	done

	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get all members with token $token, returned status $status, content $content >&2
		exit 4
	fi


	if [[ "$VERBOSE" == "true" ]]; then
		echo "POST $MASHERY_API_BASE/v3/rest/members Response = "$output >&2
	fi
	
	echo ${content}

}


# Get member applications
function getMemberApplications() {
	local token=$1
	local memberId=$2
	local status=0
	local retry=1
	sleep $THROTTLE

	
	while [ $retry -le $RETRIES ]; do
		output=$(curl -w "\n%{http_code}\n" -s -H "Authorization: Bearer $token" "$MASHERY_API_BASE/v3/rest/members/$memberId/applications?fields="$MEMBERAPPLICATION_FIELDS"&limit=$LIMIT")
		status=$(echo "$output" | tail -1)
		content=$(echo "$output" | head -1)

		if [[ $status -eq 200 ]]; then
			break
		fi

		if [[ $status -eq 404 ]]; then
			echo $NAME: failed to get all member applications with token $token, returned status $status, content $content >&2
			exit 4
		fi

		retry=$(( $retry + 1 ))
		sleep $(( 2 * $retry )) # throttle
		token=$(getToken $AREA)
	done

	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get all member applications with token $token, returned status $status, content $content >&2
		exit 4
	fi


	if [[ "$VERBOSE" == "true" ]]; then
		echo "POST $MASHERY_API_BASE/v3/rest/members/$memberId/applications Response = "$output >&2
	fi
	
	echo ${content}

}

function main() {

	# Check all dependencies installed
	getDependencies

	# Set variables from command line options
	setopts $*

	# Get a token
	local token=$(getToken $AREA)

	# Get all member identifiers
	local members=$(getAllMembers $token)
	local totalMembers=$(echo "${members}" | jq -r '. | length')


	if [[ $totalMembers == 0 ]]; then
		echo "No Members found in area '$AREA'"
		exit 5
	else
	
		local i=1
		local json=""
		for memberId in $(echo "${members}" | jq -r '.[].id'); do


			local member=$(getMember $token $memberId)
			local memberApplications=$(getMemberApplications $token $memberId)

						
			if [[ $totalMembers == 1 ]]; then
				json=$(echo "[{\"member\":" ${member} ",\"applications\":" ${memberApplications} "}]")
				break				
			else 
				local ln=""
				if [[ $i == 1 ]]; then
					ln=$(echo "[{\"member\":" ${member} ",\"applications\":" ${memberApplications} "}")
				elif [[ $i < $totalMembers ]]; then
					ln=$(echo ",{\"member\":" ${member} ",\"applications\":" ${memberApplications} "}")
				else 
					ln=$(echo ",{\"member\":" ${member} ",\"applications\":" ${memberApplications} "}]")
				fi

				json="${json}${ln}"
			fi

			((i++))

		done
			
	fi

	echo "$json"
	exit 0

}

main $*

exit 0
