# aws-manual-change-detector

Make CloudTrail Useful with Automatic Filtering and Alerts


This repository provides an example as to how one can create a relatively simple solution to 
monitoring CloudTrail for unwanted events. The basis of this method is to use a CloudWatch 
filter to gather only the events that are desired to alert on, and trigger a lambda from this 
filter.


## Architecture

CloudTrail -> CloudWatch Logs -> CloudWatch Log Filter -> Lambda -> Alert

It is preferable to use a pre-existing CloudTrail and CloudWatch log group that contains the mentioned 
CloudTrail events(for billing purposes). It is recommended to use a CloudTrail that is applied to all 
regions and records read/write and KMS events for maximum coverage, although this is all up to the user. 
If you do not currently have a CloudTrail that sends events to a Cloudwatch log group, you will need to 
set this up in addition to the rest of this project. 

The next part of this project is the most important and the most configurable: the Cloudwatch Log Filter.
The Cloudwatch log filter will filter the events in your logs and trigger a lambda. This needs to be 
customized according to what events you want to alert on and how your AWS environment is set up. In this 
example, it is desired to alert on any manual changes made to infrustructure that are done by an employee 
directly. This means we are filtering for any event that is not a read operation and is done by a Federated 
User. Depending on your use case, you will need to update the events in `cloudwatch_filter_events` in the 
`resources.tf` file. It is necessary in *all* cases to update the `filter_pattern` in `manual_change_filter` 
in the same file to include or exclude specific user identities depending on your infrastructure. This part 
of the project requires manual testing against the Cloudwatch log group to get the best results.

The aforementioned filter has a `destination` set to the lambda that will be used to alert on these events. 
The filter must be given permission to invoke the lambda which is reflected in the terraform. Once the payload 
in sent to the lambda function, it will be parsed to make the alert more meaningful and then sent to the Slack 
channel matching the user-supplied webhook. The lambda currently parses the AWS account in which the 
action took place, the event name, event source, event time, the role used to complete the action, the user that 
had assumed the role, the source IP address, and any params sent with the request.This lambda can be configured 
to perform different alerting functions such as SNS or email alerts, or it can be configured to take actions such 
as removing access from a user in the event, etc (further permissions will need to be added to the lambda when customizing).

