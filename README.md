- aws cli needs to be configured with a user with sufficient rights to modify the lambda function

# Publish Lambda function

A [Wercker](http://wercker.com/) step for creating or updating an AWS Lambda function. It will create the function if it does not exist or it will update it in case it already exists.
As a prerequisite, the [AWS Command Line Interface](https://aws.amazon.com/cli/) needs to be already configured with the details of a user which has sufficient _AWS Lambda_ management privileges.

The step takes several arguments:

* **function-name**: The name of the Lambda function.
* **handler**: The actual function that will be executed (handler).
* **aws-account-id**: The AWS Account Id under which theLambda function needs to be published.
* **lambda-role**: The AWS IAM Role that needs to be associated with the Lambda function to control its execution privileges.
* **archive**: The path to zip archive that contains the function (alternatively use s3-artefact).
* **s3-artefact**: The S3 path to the artefact that contains the function (alternatively use archive).
* **runtime**: A runtime according to the documentation for `--runtime` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation. Default is `nodejs4.3`.
* **timeout**: An integer value according to the documentation for `--timeout` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation. Default is `3` seconds.
* **memory-size**: An integer value according to the documentation for `--memory-size` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation. Default is `128` Mb.
* **vpc-subnet-ids**: A comma-separated list of VPC subnet IDs in which to deploy this function. Only required when deploying to a custom VPC. For more details, see the documentation for `--vpc-config` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation.
* **vpc-security-group-ids**: A comma-separated list of VPC security group IDs to attach to this function. Only required when deploying to a custom VPC. For more details, see the documentation for `--vpc-config` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation.
* **error-sns-topic**: The SNS topic to notify when this Lambda function fails. When this argument is not set, no CloudWatch alarm is created and thereby error notifications are not enabled.
* **events-source-arn**: The _ARN_ of a _DynamoDB_ or _Kinesis Stream_ to be used as source for events that trigger the function execution and provide the input. For more details, see the documentation for _create-event-source-mapping_ in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-event-source-mapping.html) documentation. Some defaults have been provided.
* **events-source-batch-size**: The batch size for the stream specified with **events-source-arn**.
* **description**: The description of the Lambda function.
* **environment**: A string representing the environment variables set for this function. Please refer to the documentation for `--environment` in [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html). Eg: `KeyName1=string,KeyName2=string`
* **tags**: A string representing the list of tags to set for this function. Please refer to the documentation for `tag-resource` in [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/tag-resource.html). Eg: `KeyName1=string,KeyName2=string`
* **tracing**: Set to 'true' for enabling X-Ray Active tracing. 

## Examples

A `NodeJS` function that uses code on S3 and default values for optional parameters.

```
steps:
    - audienceproject/publish-lambda-function:
        function-name: HelloWorld
        handler: src/handler.handler
        aws-account-id: 1234567890
        lambda-role: SomeRoleThatAllowsExecution
        s3-artefact: s3://my-artefacts-bucket/project/functions.zip
        environment: 'USER=world,ACTION=hello'
```

A `NodeJS` function that uses code in zip archive and default values for optional parameters.

```
steps:
    - audienceproject/publish-lambda-function:
        function-name: HelloWorld
        handler: src/handler.handler
        aws-account-id: 1234567890
        lambda-role: SomeRoleThatAllowsExecution
        archive: fileb://$WERCKER_SOURCE_DIR/code.zip      
```

A `Java` function using code on S3 that explicitely sets values for optional parameters.

```
steps:
    - audienceproject/publish-lambda-function:
        function-name: GoodBye
        handler: com.myorganization.lambda.Greeter::goodBye
        aws-account-id: 1234567890
        lambda-role: SomeRoleThatAllowsExecution
        s3-artefact: s3://my-artefacts-bucket/project/artefact.jar
        runtime: java8
        timeout: 50
        memory-size: 1024
        error-sns-topic: arn:aws:sns:us-east-1:1234567890:exceptions
```

A VPC-enabled `NodeJS` function.

```
steps:
    - audienceproject/publish-lambda-function:
        function-name: HelloWorld
        handler: src/handler.handler
        aws-account-id: 1234567890
        lambda-role: SomeRoleThatAllowsExecution
        s3-artefact: s3://my-artefacts-bucket/project/functions.zip      
        vpc-subnet-ids: subnet-asafe6f4,subnet-cffcbbe7
        vpc-security-group-ids: sg-d845fea3,sg-df47fe33,sg-d82345g3
```
