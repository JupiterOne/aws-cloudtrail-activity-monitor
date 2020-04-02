export interface AWSEvent {
  awslogs: {
    data: string;
  }
}


export interface AWSCloudwatchEvent {
  messageType: string;
  owner: string;
  logGroup: string;
  logStream: string;
  subscriptionFilters: string[];
  logEvents: LogEvent[];
}

export interface LogEvent {
  id: string;
  timestamp: Date;
  message: string;
}


export interface EventInfo {
  errorCode: string;
  account: string;
  name: string;
  source: string;
  time: Date;
  region: string;
  role: string;
  username: string;
  ip: string;
  requestParams: string;
}
