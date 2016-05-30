#!/bin/bash
R='^s3:\/\/([^\/\S]+?)\/(.+)$'
I=$ENV{$5}
if [[ $I =~ $R ]]
then
    BUCKET=${BASH_REMATCH[1]}
    KEY=${BASH_REMATCH[2]}
else
    echo "$I is not a valid S3 path"
    exit 1;
fi
if [ $(aws lambda list-functions | jq '.Functions[].FunctionName | select( . == "'$ENV{$1}'" )' | wc -c) -ne 0 ]
then
    aws lambda update-function-configuration --function-name $ENV{$1} --role "arn:aws:iam::$ENV{$3}:role/$ENV{$4}" --handler $ENV{$2} --timeout $ENV{$7} --memory-size $ENV{$8}
    aws lambda update-function-code --function-name $ENV{$1} --s3-bucket $BUCKET --s3-key $KEY
else
    aws lambda create-function --function-name $ENV{$1} --runtime $ENV{$6} --role "arn:aws:iam::$ENV{$3}:role/$ENV{$4}" --handler $ENV{$2} --code S3Bucket=$BUCKET,S3Key=$KEY --timeout $ENV{$7} --memory-size $ENV{$8}
fi
