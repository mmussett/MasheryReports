# TIBCO API Management Scripts

Set of shell scripts to invoke TIBCO Cloud API Management APIs

## Getting your APIM PAPI (Platform API) Service Account Credentials

You'll need PAPI Service Account Credentials in order to execute calls to the APIM Platform APIs.

Please see the online guide [here](http://docs.mashery.com/manage/GUID-69BFED6F-6414-45A1-88B9-C18CD9FF7873.html)

## Getting your APIM PAPI (Platform API) Key and Secret

Steps to access Mashery V2/V3 APIs for TIBCO cloud accounts

Each TIBCO cloud customer must use the serviceaccount user to access Mashery V2/V3 APIs.
The user looks similar like the following example: eval12345678_serviceaccount .
Only this user has the right roles and privileges to access Mashery V2/V3 APIs.

Steps to acces Mashery V2/V3 using service account user:
1. Login to developer portal: https://developer.mashery.com/ using service account credentials.
2. Generate an access token by using the IO-Doc: https://developer.mashery.com/io-docs or The Mashery v3 API token: https://developer.mashery.com/docs/read/mashery_api/30/Authentication 
3. Now you are able to use and access Mashery V2/V3 APIs listed in our Developer Portal: https://developer.mashery.com/docs/read/mashery_api


## Reports

* getEndpointCallTransformation - Get Call Transformation data for all endpoints.
* getEndpointSecurity - Get security details for endpoints.
* [getCallsDeveloperActivityForService](#getcallsdeveloperactivityforservice) - Get Calls by Developer for a particular API Service




## getCallsDeveloperActivityForService

* Return the call traffic volumes for a particular date for a given Service Key (API Service Identifier).
* One record per API Key is returned.


For API Documentation please refer to [here](https://developer.mashery.com/docs/read/mashery_api/20_reporting/REST_Resources#CallsDeveloperActivityForService)

```
usage: getCallsDeveloperActivityForService.sh -u username -p password -k apiKey -s apiSecret -a areaUuid -d apiDefinition -t YYYY-MM-DD -v true

	Get all developer activity analytics report for a service.

args:

	-u Authorisation Username
	-p Authorisation Password
	-k API Client Key
	-s API Client Secret
	-a APIM Area Identifier
	-d Service Key (SPKEY)
 	-t Reporting Date (in YYYY-MM-DD format e.g. -t 2023-03-01)
	[-v] Verbose Flag (-v true)

	getCallsDeveloperActivityForService.sh -u dev@tibco.com -p mypwd123 -k 5cwt42e494bb4h7fkxsh6xh6 -s Sq4UjgLZ2U -a 12b2de7a-c456-4cc0-893d-5bbf3123be2b -d 2mf7trqbz84nr8j6kx848er5 -t 2023-03-01 > 2mf7trqbz84nr8j6kx848er5.json
```

Example


```
./getCallsDeveloperActivityForService.sh -u apim_serviceaccount -p abc123 -k abc123 -s XsFNXxjjaT -a abc123-abcd-efgh-i1j2-baeeaacavb67 -d kkksd4jdga4v8y7dmeh8914m5 -t 2023-03-01 | jq


{
  "startDate": "2023-03-01T00:00:00Z",
  "endDate": "2023-03-01T23:59:59Z",
  "serviceKey": "<redacted>",
  "serviceDevKey": "<redacted>",
  "callStatusSuccessful": 288,
  "callStatusBlocked": 0,
  "callStatusOther": 0,
  "userName": "<redacted>",
  "applicationName": "Postman",
  "company": "",
  "email": "<redacted>",
  "auditInfo": "1691663405 CallsDeveloperActivityForService"
}
```