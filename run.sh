#!/bin/bash
R='^s3://([^/]+)/(.+)$'
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT ]]; then
    if [[ $WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT =~ $R ]]; then
        BUCKET=${BASH_REMATCH[1]}
        KEY=${BASH_REMATCH[2]}
    else
        echo "$WERCKER_PUBLISH_LAMBDA_FUNCTION_S3_ARTEFACT is not a valid S3 path"
        exit 1
    fi
elif [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_ARCHIVE ]]; then
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

# Validate VPC settings
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_VPC_SECURITY_GROUP_IDS ]]; then
    if [[ -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_VPC_SUBNET_IDS ]]; then
        echo "Please set vpc-subnet-ids when setting vpc-security-group-ids"
        exit 1
    fi
fi

# Create '--vpc-config' cli argument
VPC_CONFIG=
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_VPC_SUBNET_IDS ]]; then
    VPC_CONFIG="--vpc-config SubnetIds=${WERCKER_PUBLISH_LAMBDA_FUNCTION_VPC_SUBNET_IDS}"
fi
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_VPC_SECURITY_GROUP_IDS ]]; then
    VPC_CONFIG="${VPC_CONFIG},SecurityGroupIds=${WERCKER_PUBLISH_LAMBDA_FUNCTION_VPC_SECURITY_GROUP_IDS}"
fi

if [[ ! -z $VPC_CONFIG ]]; then
    echo "VPC configuration: ${VPC_CONFIG}"
fi

ENV_CONFIG=
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_ENVIRONMENT ]]; then
    ENV_CONFIG="--environment Variables={${WERCKER_PUBLISH_LAMBDA_FUNCTION_ENVIRONMENT}}"
fi

DESC_CONFIG=
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_DESCRIPTION ]]; then
    DESC_CONFIG="--description \"${WERCKER_PUBLISH_LAMBDA_FUNCTION_DESCRIPTION}\""
fi

echo "Looking for existing function with name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME"
if [ $(aws lambda list-functions | jq '.Functions[].FunctionName | select( . == "'$WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME'" )' | wc -c) -ne 0 ];
then
    echo "Function found..."
    aws --debug lambda update-function-configuration --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME $VPC_CONFIG --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE $DESC_CONFIG $ENV_CONFIG
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
        aws --debug lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME $VPC_CONFIG --runtime $WERCKER_PUBLISH_LAMBDA_FUNCTION_RUNTIME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --code S3Bucket=$BUCKET,S3Key=$KEY --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE $DESC_CONFIG $ENV_CONFIG
    else
        echo "Creating Lambda function with code from local zip archive"
        aws --debug lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME $VPC_CONFIG --runtime $WERCKER_PUBLISH_LAMBDA_FUNCTION_RUNTIME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --zip-file $ARCHIVE --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE $DESC_CONFIG $ENV_CONFIG
    fi
fi

if [[ ! -z ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ERROR_SNS_TOPIC} ]]; then
    ALARM_NAME="${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME}-Errors"

    echo "Creating alarm ${ALARM_NAME}"
    aws cloudwatch put-metric-alarm --alarm-name ${ALARM_NAME} \
        --period 300 --namespace 'AWS/Lambda' \
        --statistic Average --threshold 0 --metric-name Errors --evaluation-periods 1 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=FunctionName,Value=${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} \
        --alarm-actions "${WERCKER_PUBLISH_LAMBDA_FUNCTION_ERROR_SNS_TOPIC}"
fi


if [[ ! -z ${WERCKER_PUBLISH_LAMBDA_FUNCTION_EVENTS_SOURCE_ARN} ]]; then
    echo "Creating Lambda trigger."
    CNT=$(aws lambda list-event-source-mappings --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} --event-source-arn ${WERCKER_PUBLISH_LAMBDA_FUNCTION_EVENTS_SOURCE_ARN} --query "length(EventSourceMappings[*])")
    if [[ "$CNT" == "0" ]]; then
        aws lambda create-event-source-mapping \
            --event-source-arn ${WERCKER_PUBLISH_LAMBDA_FUNCTION_EVENTS_SOURCE_ARN} \
            --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} \
            --batch-size ${WERCKER_PUBLISH_LAMBDA_FUNCTION_EVENTS_SOURCE_BATCH_SIZE} \
            --starting-position TRIM_HORIZON
        echo "Added new trigger."
    fi
else
    echo "Removing triggers becuase none were specified."
    uuids=$(aws lambda list-event-source-mappings --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} --query "EventSourceMappings[0].UUID" --output text)
    for uid in $uuids
    do
        aws lambda delete-event-source-mapping --uuid $uuid
    done
fi
