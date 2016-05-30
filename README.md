- aws cli needs to be configured with a user with sufficient rights to modify the lambda function

# Publish Lambda function

A [Wercker](http://wercker.com/) step for creating or updating an AWS Lambda function. It will create the function if it does not exist or it will update it in case it already exists.
As a prerequisite, the [AWS Command Line Interface](https://aws.amazon.com/cli/) needs to be already configured with the details of a user which has sufficient _AWS Lambda_ management privileges.

The step takes several arguments:

* **name**: The name of the Lambda function.
* **handler**: The actual function that will be executed (handler).
* **aws-account-id**: The AWS Account Id under which theLambda function needs to be published.
* **lambda-role**: The AWS IAM Role that needs to be associated with the Lambda function to control its execution privileges.
* **s3-artefact**: The S3 path to the artefact that contains the function.
* **runtime**: A runtime according to the documentation for `--runtime` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation. Default is `nodejs4.3`.
* **timeout**: An integer value according to the documentation for `--timeout` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation. Default is `3` seconds.
* **memory-size**: An integer value according to the documentation for `--memory-size` in the [AWS cli](http://docs.aws.amazon.com/cli/latest/reference/lambda/create-function.html) documentation. Default is `128` Mb.

runtime:
  type: string
  required: false
  default: nodejs4.3
timeout:
  type: string
  required: false
  default: 3
memory-size:
  type: string
  required: false
  default: 128

## Examples

The first example is for a `NodeJS` function that takes in the default values fro the optional parameters.

```
steps:
    - audienceproject/publish-lambda-function:
        - name: HelloWorld
        - handler: src/handler.handler
        - aws-account-id: 1234567890
        - lambda-role: SomeRoleThatAllowsExecution
        - s3-artefact: s3://my-artefacts-bucket/project/functions.zip      
```

The second example is for a `Java` function that needs a little more then the default values.

```
steps:
    - audienceproject/publish-lambda-function:
        - name: GoodBye
        - handler: com.myorganization.lambda.Greeter::goodBye
        - aws-account-id: 1234567890
        - lambda-role: SomeRoleThatAllowsExecution
        - s3-artefact: s3://my-artefacts-bucket/project/artefact.jar
        - runtime: java8
        - timeout: 50
        - memory-size: 1024      
```
