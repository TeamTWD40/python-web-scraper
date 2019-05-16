#!/bin/bash

internalApiDNS=$1
containerPort=$2
appName=$3
region=$4
stage=$5
apiDNS=$6

restApi=`aws apigateway get-rest-apis | jq --arg appName "$appName" '.items[] | select(.name==$appName) | .id' -r` || echo "Rest Api Not Found"

if [ -z "$restApi" ]
then
    restApi=`aws apigateway create-rest-api --name $appName --description 'Rest API for $appName' --endpoint-configuration types=REGIONAL | jq '.id' -r`
fi

vpc_linkId=`aws apigateway get-vpc-links --region $region | jq '.items[].id' -r`

proxyResource_id=$(aws apigateway get-resources --rest-api-id $restApi | jq '.items[] | select(.pathPart=="{proxy+}") | .id' -r) || echo "Resource does not exist"
if [ -z "$proxyResource_id" ]
then 
    proxyResource_id=$(aws apigateway create-resource --rest-api-id $restApi --parent-id $(aws apigateway get-resources --rest-api-id $restApi | jq '.items[].id' -r) --path-part {proxy+} | jq '.id' -r)
    aws apigateway put-method --rest-api-id $restApi --resource-id $proxyResource_id --http-method ANY --authorization-type "NONE" --no-api-key-required --request-parameters "method.request.path.proxy=true" 
    aws apigateway put-integration --rest-api-id $restApi --resource-id $proxyResource_id --http-method ANY --type HTTP_PROXY --integration-http-method ANY --uri "http://${internalApiDNS}:${containerPort}/{proxy}" --connection-type VPC_LINK --connection-id $vpc_linkId --request-parameters "integration.request.path.proxy"="method.request.path.proxy" 
    aws apigateway put-integration-response --rest-api-id $restApi --resource-id $proxyResource_id --http-method ANY --status-code 200 --selection-pattern ""
else
    aws apigateway delete-integration --rest-api-id $restApi --resource-id $proxyResource_id --http-method ANY
    aws apigateway put-integration --rest-api-id $restApi --resource-id $proxyResource_id --http-method ANY --type HTTP_PROXY --integration-http-method ANY --uri "http://${internalApiDNS}:${containerPort}/{proxy}" --connection-type VPC_LINK --connection-id $vpc_linkId --request-parameters "integration.request.path.proxy"="method.request.path.proxy"
    aws apigateway put-integration-response --rest-api-id $restApi --resource-id $proxyResource_id --http-method ANY --status-code 200 --selection-pattern ""
fi

aws apigateway create-deployment --rest-api-id $restApi --stage-name $stage --cache-cluster-enabled --cache-cluster-size '0.5'
sleep 6
if [ $stage == "production" ]
then 
    aws apigateway create-base-path-mapping --domain-name $apiDNS --rest-api-id $restApi --stage $stage --base-path $appName || echo "Path mapping already exists"
else
    aws apigateway create-base-path-mapping --domain-name $stage-$apiDNS --rest-api-id $restApi --stage $stage --base-path $appName || echo "Path mapping already exists"
fi
