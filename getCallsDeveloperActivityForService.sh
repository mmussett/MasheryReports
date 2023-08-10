#!/bin/bash

# Get summary of API calls made per developer for a Service.
# Output in CSV.

# (c) 2022 TIBCO Software Inc.
#The following information is confidential information of TIBCO Software Inc. Use, duplication, transmission, or republication for any purpose #without the prior written consent of TIBCO is expressly prohibited.

#This document (including, without limitation, any product roadmap or statement of direction data) illustrates the planned testing, release and availability dates for TIBCO products and services. This document is provided for informational purposes only and its contents are subject to change without notice. TIBCO makes no warranties, express or implied, in or relating to this document or any information in it, including, without limitation, that this document, or any information in it, is error-free or meets any conditions of merchantability or fitness for a particular purpose. This document may not be reproduced or transmitted in any form or by any means without our prior written permission.
#The material provided is for informational purposes only, and should not be relied on in making a purchasing decision. The information is not a commitment, promise or legal obligation to deliver any material, code, or functionality. The development, release, and timing of any features or functionality described for our products remain at our sole discretion.
#In this document TIBCO or its representatives may make forward-looking statements regarding future events, TIBCO's future results or our future financial performance. These statements are based on management's current expectations. Although we believe that the expectations reflected in the forward-looking statements contained in this document are reasonable, these expectations or any of the forward-looking statements could prove to be incorrect and actual results or financial performance could differ materially from those stated herein. TIBCO does not undertake to update any forward-looking statement that may be made from time to time or on its behalf.

# 20221114 - MMussett - First version (for GATX).


#
# Debug
#set -x
# Script name
NAME="$(basename $0)"
# Mashery API base
MASHERY_API_BASE="https://api.mashery.com"
# Report endpoint
DEVELOPER_ACTIVITY_REPORT_API_URL="$MASHERY_API_BASE/v3/rest/reports/calls/developer_activity/service"
# 
# Sleep between requests
THROTTLE=1.25
# Request retries
RETRIES=3
# Maximum number of services
LIMIT=1000


# Output usage information
function usage() {
	echo "usage: $NAME -u username -p password -k apiKey -s apiSecret -a areaUuid -d apiDefinition -t YYYY-MM-DD -v true"
	echo ""
	echo "	Get all developer activity analytics report for a service."
	echo ""
	echo "args:"
	echo ""
	echo "	-u Authorisation Username"
	echo "	-p Authorisation Password"
	echo "	-k API Client Key"
	echo "	-s API Client Secret"
	echo "	-a APIM Area Identifier"
	echo "	-d Service Key (SPKEY)"
	echo " 	-t Reporting Date (in YYYY-MM-DD format e.g. -t 2023-03-01)"
	echo "	[-v] Verbose Flag (-v true)"
	echo ""
	echo "	$NAME -u dev@tibco.com -p mypwd123 -k 5cwt42e494bb4h7fkxsh6xh6 -s Sq4UjgLZ2U -a 12b2de7a-c456-4cc0-893d-4bbf3123be2b -d 2mf7trqbz84nr8j6kx848er5 -t 2023-03-01 > 2mf7trqbz84nr8j6kx848er5.json"
	echo ""

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
	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get token for area $1, returned status $status, response ${output[0]} >&2
		exit 3
	else
		token=$(echo ${output[0]} | jq -r '.access_token')
	fi
	echo $token
}

# Set options
function setopts() {

	# Get command line options
	while getopts :a:b:k:p:s:u:d:t:v: opt; do
	  case ${opt} in
			a ) # area
				AREA="$OPTARG"
	      ;;
			d ) # API definition (service)
				SERVICE="$OPTARG"
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
			t ) # date
				REPORTDATE="$OPTARG"
		  ;;
		  	v ) # verbose
				VERBOSE="true";
		  ;;
	    \? ) usage
	      ;;
	  esac
	done
	shift $((OPTIND-1))


	
	# Check arguments
	if [[ "$USERNAME" == "" || "$PASSWORD" == "" || "$KEY" == "" || "$SECRET" == "" || "$AREA" == "" || "$SERVICE" == "" || "$REPORTDATE" == "" ]]; then
		usage
	fi

}

# Get activity report
function getActivityReport() {
	local token=$1
	local service=$2
	local report_date=$3
	local status=0
	local retry=1
	sleep $THROTTLE


	local start_date=$report_date"T00:00:00Z"
	local end_date=$report_date"T23:59:59Z"


	while [ $retry -le $RETRIES ]; do
		output=$(curl -w "\n%{http_code}\n" -s -H "Authorization: Bearer $token" "$DEVELOPER_ACTIVITY_REPORT_API_URL/$service?start_date=$start_date&end_date=$end_date&format=json&limit=$LIMIT")
		status=$(echo "$output" | tail -1)
		content=$(echo "$output" | head -1)
		if [[ $status -eq 200 ]]; then
			break
		fi
		retry=$(( $retry + 1 ))
		sleep $(( 2 * $retry )) # throttle
		token=$(getToken $AREA)
	done

	if [[ "$VERBOSE" == "true" ]]; then
		echo $status >&2
		echo $content >&2
	fi

	if [[ $status -ne 200 ]]; then
		echo $NAME: failed to get reporting data with token $token, returned status $status, content $content >&2
		exit 4
	fi

	report=$(echo "$content" | jq '.[]')

	echo $report
}

function main() {

	# Check all dependencies installed
	getDependencies

	# Set variables from command line options
	setopts $*

	# Get a token

	local token=$(getToken $AREA)

	getActivityReport $token $SERVICE $REPORTDATE

}

main $*

exit 0
