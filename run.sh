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
    DESC_CONFIG="--description '${WERCKER_PUBLISH_LAMBDA_FUNCTION_DESCRIPTION}'"
fi

DLQ_CONFIG=
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_DEAD_LETTER_QUEUE_ARN ]]; then
    DLQ_CONFIG="--dead-letter-config TargetArn={${WERCKER_PUBLISH_LAMBDA_FUNCTION_DEAD_LETTER_QUEUE_ARN}}"
fi

function get_lambda_state {
  aws lambda get-function \
    --function-name "$WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME" \
    --query 'Configuration.[State, LastUpdateStatus,LastUpdateStatusReason,LastUpdateStatusReasonCode]'
}

function await_modification_complete {
  while true; do
    STATES=$(get_lambda_state)
    Status=$(echo "$STATES" | jq -r '.[0]')
    LastUpdateStatus=$(echo "$STATES" | jq -r '.[1]')
    LastUpdateStatusReason=$(echo "$STATES" | jq -r '.[2]')
    LastUpdateStatusReasonCode=$(echo "$STATES" | jq -r '.[3]')
    echo "Status=${Status}, LastUpdateStatus=${LastUpdateStatus}, LastUpdateStatusReason=${LastUpdateStatusReason}, LastUpdateStatusReasonCode=${LastUpdateStatusReasonCode}"

    case $LastUpdateStatus in
    "Successful")
      ;;
    "InProgress")
      sleep 2
      continue
      ;;
    *)
      echo "LastUpdateStatus error"
      exit 1
      ;;
    esac

    case $Status in
    "Active")
      ;;
    "Inactive")
      ;;
    "Pending")
      sleep 2
      continue
      ;;
    *)
      echo "Status error"
      exit 1
      ;;
    esac

    # If we get this far everything is ok
    break
  done
}

echo "Looking for existing function with name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME"
if [ $(aws lambda list-functions | jq '.Functions[].FunctionName | select( . == "'$WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME'" )' | wc -c) -ne 0 ];
then
    echo "Function found..."

    aws lambda update-function-configuration --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME $VPC_CONFIG --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE $DESC_CONFIG $ENV_CONFIG $DLQ_CONFIG
    [ $? -eq 0 ] || exit $?
    await_modification_complete

    if [[ ! -z ${BUCKET+x} && ! -z ${KEY+x} ]]; then
        echo "Updating Lambda function with code from S3"
        FUNCTION_DESCRIPTION=$(aws lambda update-function-code --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --s3-bucket $BUCKET --s3-key $KEY --publish)
        [ $? -eq 0 ] || exit $?
        echo "Function updated: ${FUNCTION_DESCRIPTION}"
    else
        echo "Updating Lambda function with code from local zip archive"
        FUNCTION_DESCRIPTION=$(aws lambda update-function-code --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME --zip-file $ARCHIVE --publish)
        [ $? -eq 0 ] || exit $?
        echo "Function updated: ${FUNCTION_DESCRIPTION}"
    fi

    await_modification_complete
else
    echo "Function not found..."
    if [[ ! -z ${BUCKET+x} && ! -z ${KEY+x} ]]; then
        echo "Creating Lambda function with code from S3"
        FUNCTION_DESCRIPTION=$(aws lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME $VPC_CONFIG --runtime $WERCKER_PUBLISH_LAMBDA_FUNCTION_RUNTIME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --code S3Bucket=$BUCKET,S3Key=$KEY --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE $DESC_CONFIG $ENV_CONFIG $DLQ_CONFIG --publish)
        [ $? -eq 0 ] || exit $?
        echo "Function created: ${FUNCTION_DESCRIPTION}"
    else
        echo "Creating Lambda function with code from local zip archive"
        FUNCTION_DESCRIPTION=$(aws lambda create-function --function-name $WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME $VPC_CONFIG --runtime $WERCKER_PUBLISH_LAMBDA_FUNCTION_RUNTIME --role "arn:aws:iam::$WERCKER_PUBLISH_LAMBDA_FUNCTION_AWS_ACCOUNT_ID:role/$WERCKER_PUBLISH_LAMBDA_FUNCTION_LAMBDA_ROLE" --handler $WERCKER_PUBLISH_LAMBDA_FUNCTION_HANDLER --zip-file $ARCHIVE --timeout $WERCKER_PUBLISH_LAMBDA_FUNCTION_TIMEOUT --memory-size $WERCKER_PUBLISH_LAMBDA_FUNCTION_MEMORY_SIZE $DESC_CONFIG $ENV_CONFIG $DLQ_CONFIG --publish)
        [ $? -eq 0 ] || exit $?
        echo "Function created: ${FUNCTION_DESCRIPTION}"
    fi

    await_modification_complete
fi

# Create Lambda alias
if [[ ! -z ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ALIAS} ]]; then
    # Find version number of newly published function
    FUNCTION_VERSION=$(echo $FUNCTION_DESCRIPTION | jq -r .Version)

    # Check if alias exists
    if [ $(aws lambda list-aliases --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME}  --query "length(Aliases[?Name == '${WERCKER_PUBLISH_LAMBDA_FUNCTION_ALIAS}'])") -ne 0 ]; then
        echo "Alias ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ALIAS} already exists, updating it to point to version ${FUNCTION_VERSION}."
        aws lambda update-alias --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} --function-version ${FUNCTION_VERSION} --name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ALIAS}
    else
        echo "Alias ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ALIAS} does not exist. Creating it and pointing it to version ${FUNCTION_VERSION}."
        aws lambda create-alias --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} --function-version ${FUNCTION_VERSION} --name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_ALIAS}
    fi

    await_modification_complete
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

        await_modification_complete
    fi
# else
    # echo "Removing triggers becuase none were specified"
    # uuids=$(aws lambda list-event-source-mappings --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} --query "EventSourceMappings[0].UUID" --output text)
    # for uuid in $uuids
    # do
    #     aws lambda delete-event-source-mapping --uuid $uuid
    # done
fi

# Add tags
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_TAGS ]]; then
    FUNCTION_ARN=$(aws lambda get-function --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} --output text --query 'Configuration.FunctionArn')
    aws lambda tag-resource \
        --resource $FUNCTION_ARN \
        --tags "${WERCKER_PUBLISH_LAMBDA_FUNCTION_TAGS}"

    await_modification_complete
fi

# Add tracing
if [[ ! -z $WERCKER_PUBLISH_LAMBDA_FUNCTION_TRACING ]]; then
    echo "Adding Active tracing"
    aws lambda update-function-configuration \
        --function-name ${WERCKER_PUBLISH_LAMBDA_FUNCTION_FUNCTION_NAME} \
        --tracing-config Mode=Active

    await_modification_complete
fi
