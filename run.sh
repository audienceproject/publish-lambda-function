#!/bin/bash
R='^s3:\/\/([^\/\S]+?)\/(.+)$'
if [[ $WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT =~ $R ]]
then
    BUCKET=${BASH_REMATCH[1]}
    KEY=${BASH_REMATCH[2]}
else
    echo "$WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT is not a valid S3 path"
    exit 1;
fi
if [ $(aws lambda list-functions | jq '.Functions[].FunctionName | select( . == "'$WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME'" )' | wc -c) -ne 0 ]
then
    aws lambda update-function-configuration --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --role "arn:aws:iam::$ENV{$3}:role/$ENV{$4}" --handler $ENV{$2} --timeout $ENV{$7} --memory-size $ENV{$8}
    aws lambda update-function-code --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --s3-bucket $BUCKET --s3-key $KEY
else
    aws lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --runtime $ENV{$6} --role "arn:aws:iam::$ENV{$3}:role/$ENV{$4}" --handler $ENV{$2} --code S3Bucket=$BUCKET,S3Key=$KEY --timeout $ENV{$7} --memory-size $ENV{$8}
fi
