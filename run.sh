#!/bin/bash
R='^s3://([^/]+)/(.+)$'
if [[ ! -z ${WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT+x} ]]; then
    if [[ $WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT =~ $R ]]; then
        BUCKET=${BASH_REMATCH[1]}
        KEY=${BASH_REMATCH[2]}
    else
        echo "$WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT is not a valid S3 path"
        exit 1
    fi
elif [[ ! -z ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ARCHIVE+x} ]]; then
    if [[ -f $WERCKER_PUBLISH_LAMBDA_FUNCTION_ARCHIVE ]]; then
        echo "$WERCKER_PUBLISH_LAMBDA_FUNCTION_ARCHIVE does not exist"
        exit 1
    else
        echo "Lambda code will be fetched from zipped archive"
        ARCHIVE=$WERCKER_PUBLISH_LAMBDA_FUNCTION_ARCHIVE
    fi
    #statements
else
    echo "You must set either archive or s3-artefact"
    exit 1
fi

echo "Looking for existing function with name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME"
if [ $(aws lambda list-functions | jq '.Functions[].FunctionName | select( . == "'$WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME'" )' | wc -c) -ne 0 ];
then
    echo "Function found..."
    aws lambda update-function-configuration --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE
    if [[ ! -z ${BUCKET+x} && ! -z ${KEY+x} ]]; then
        echo "Updating Lambda function with code from S3"
        aws lambda update-function-code --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --s3-bucket $BUCKET --s3-key $KEY
    else
        echo "Updating Lambda function with code from local zip archive"
        aws lambda update-function-code --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --zip-file $ARCHIVE
    fi
else
    echo "Function not found..."
    if [[ ! -z ${BUCKET+x} && ! -z ${KEY+x} ]]; then
        echo "Creating Lambda function with code from S3"
        aws lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --runtime $WERCKER_PUBLISH_LAMBDA_FUNCTION_RUNTIME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --code S3Bucket=$BUCKET,S3Key=$KEY --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE
    else
        echo "Creating Lambda function with code from local zip archive"
        aws lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --runtime $WERCKER_PUBLISH_LAMBDA_FUNCTION_RUNTIME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --zip-file $ARCHIVE --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE
    fi
fi
