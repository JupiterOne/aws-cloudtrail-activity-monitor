//add or delete items in this list to change what actions will cause notifications
variable "cloudwatch_filter_events" {
  type    = "list"
  default = [
    "($.eventName!= Test*) &&",
    "($.eventName!= Reboot*) &&",
    "($.eventName!= Decrypt*) &&",
    "($.eventName!= Renew*) &&",
    "($.eventName!= Switch*) &&",
    "($.eventName!= Describe*) &&",
    "($.eventName!= Head*) &&",
    "($.eventName!= List*) &&",
    "($.eventName!= Get*) &&",
    "($.eventName!= Lookup*) &&",
    "($.eventName!= Estimate*) &&",
    "($.eventName!= BatchGet*) &&",
    "($.eventName!= Stop*) &&",
    "($.eventName!= ExitRole) &&",
    "($.eventName!= AdminList*) &&",
    "($.eventName!= AdminGet*) &&",
    "($.eventName!= AddCommunication*)"
  ]
}


resource "aws_iam_policy" "cloudwatch_for_lambda" {
  name = "CloudwatchFilterForLambdaPolicy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:ListAccountAliases"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
EOF
}


resource "aws_iam_role" "manual_change_lambda_role" {
  name = "ManualChangeDetectorLambdaRole"

  assume_role_policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "lambda.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF
}


resource "aws_iam_role_policy_attachment" "cloudwatch_lambda_role_attach" {
  role = "${aws_iam_role.manual_change_lambda_role.name}"
  policy_arn = "${aws_iam_policy.cloudwatch_for_lambda.arn}"
}


resource "aws_lambda_function" "manual_change_detector_lambda" {
  filename = "./terraform/dist/lambdas/manual-change-detector.js.zip"
  function_name = "manual-change-detector-lambda"
  role          = "${aws_iam_role.manual_change_lambda_role.arn}"
  handler = "manual-change-detector.handler"

  memory_size = 256
  timeout = 30
  runtime = "nodejs14.x"

}


resource "aws_cloudwatch_log_subscription_filter" "manual_change_filter" {
  name            = "manual_change_filter"
  log_group_name  = "/aws/cloudtrail/YourCloudTrailLogGroup"
  filter_pattern  = <<EOF
{ ($.userIdentity.arn != "arn:aws:sts::${var.target_aws_account_id}:assumed-role/*/this-depends-on-your-needs") && ($.userIdentity.arn = "arn:aws:sts::${var.target_aws_account_id}:assumed-role/*/this-depends-on-your-needs") && ${join(" ", var.cloudwatch_filter_events)} }EOF
  destination_arn = "${module.manual_change_detector_lambda.function_arn}"
}



resource "aws_lambda_permission" "invoke_lambda_by_cloudwatch_filter" {
  statement_id   = "AllowExecutionFromCloudWatchFilter"
  action         = "lambda:InvokeFunction"
  function_name  = "${module.manual_change_detector_lambda.function_arn}"
  principal      = "logs.${var.target_aws_region}.amazonaws.com"
  source_arn     = "arn:aws:logs:${var.target_aws_region}:${var.target_aws_account_id}:log-group:/aws/cloudtrail/YourCloudTrailLogGroup:*"
  source_account = "${var.target_aws_account_id}"
}