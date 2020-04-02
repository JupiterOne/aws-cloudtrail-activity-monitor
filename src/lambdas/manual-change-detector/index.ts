import SlackWebhook from 'slack-webhook'; //this is the only external dependency
import IAM from 'aws-sdk/clients/iam';
import zlib from 'zlib';
import {
    AWSEvent,
    AWSCloudwatchEvent,
    EventInfo,
} from "./types";

declare const Buffer;

export async function handler(event: AWSEvent): Promise<void> {
    const iam = new IAM();
    const alias: string = (await iam.listAccountAliases().promise()).AccountAliases[0]; //this is only necessary if you have multiple AWS accounts

    const hookUrl: string = "your-slack-webhook-value";
    const slack: SlackWebhook = new SlackWebhook(hookUrl);

    const payload = Buffer.from(event.awslogs.data, 'base64');
    zlib.gunzip(payload, function (e, result) { //get the CloudWatch payload in plaintext
        const eventData: AWSCloudwatchEvent = JSON.parse(result.toString('ascii'));

        for (const cwEvent of eventData.logEvents) {
            const cwMessage = JSON.parse(cwEvent.message);
            const awsPrincipal = cwMessage.userIdentity.arn.split(":")[5];

            const eventInfo: EventInfo = {
                account: alias,
                name: cwMessage.eventName,
                source: cwMessage.eventSource,
                errorCode:
                    typeof cwMessage.errorCode !== 'undefined'
                        ? cwMessage.errorCode
                        : "none",
                time: cwMessage.eventTime,
                region: cwMessage.awsRegion,
                role: awsPrincipal.split("/")[1],
                username: awsPrincipal.split("/")[2],
                ip: cwMessage.sourceIPAddress,
                requestParams: JSON.stringify(cwMessage.requestParameters)
            };

            const slackText: string = `
                *AWS Account*: ${eventInfo.account}\n 
                *Event Name*: ${eventInfo.name}\n 
                *Event Source*: ${eventInfo.source}\n 
                *Event Time*: ${eventInfo.time}\n
                *AWS Region*: ${eventInfo.region}\n
                *Role*: ${eventInfo.role}\n
                *Username*: ${eventInfo.username}\n
                *Source IP Address*: ${eventInfo.ip}\n
                *Request Params*: ${eventInfo.requestParams}\n
                *ErrorCode*: ${eventInfo.errorCode}\n
                *J1 Query*: ${getJ1QueryLink(cwMessage.requestParameters)}\n\n`;

            slack.send({ text: slackText });
        }
    });
}

/**
 * Parse the event params and construct a link to J1 query upon the first
 * identified resource Id or name
 */
function getJ1QueryLink(params: any): string | undefined {
    try {
        if (params) {
            Object.keys(params).forEach(key => {
                if (typeof params[key] === 'object') {
                    const url = getJ1QueryLink(params[key]);
                    if (url.length > 0) {
                        return url;
                    }
                }
                else if (key.match(/id/i) || key.match(/name/i)) {
                    return `https://lifeomic.apps.us.jupiterone.io/?query="${params[key]}"`;
                }
            });
        }
    }
    catch (err) {
        return undefined;
    }
}
