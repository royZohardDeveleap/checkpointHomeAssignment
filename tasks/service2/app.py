import os
import json
import time
import logging
from datetime import datetime
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# AWS clients
sqs_client = boto3.client('sqs', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
s3_client = boto3.client('s3', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Environment variables
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '10'))  # seconds
MAX_MESSAGES = int(os.environ.get('MAX_MESSAGES', '10'))  # max messages per poll


def process_message(message):
    """
    Process a single SQS message and upload to S3.

    Args:
        message: SQS message object

    Returns:
        bool: True if successful, False otherwise
    """
    try:
        # Parse message body
        message_body = json.loads(message['Body'])
        logger.info(f"Processing message: {message['MessageId']}")

        # Create S3 object key with timestamp and email subject
        timestamp = datetime.utcnow().strftime('%Y/%m/%d/%H')
        email_timestream = message_body.get('email_timestream', 'unknown')
        email_subject = message_body.get('email_subject', 'no-subject')

        # Sanitize subject for use in filename
        safe_subject = "".join(c if c.isalnum() or c in ('-', '_') else '_' for c in email_subject)
        safe_subject = safe_subject[:50]  # Limit length

        # Create S3 key: emails/YYYY/MM/DD/HH/<timestamp>_<subject>.json
        s3_key = f"emails/{timestamp}/{email_timestream}_{safe_subject}.json"

        # Upload to S3
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=json.dumps(message_body, indent=2),
            ContentType='application/json',
            Metadata={
                'message-id': message['MessageId'],
                'email-sender': message_body.get('email_sender', 'unknown'),
                'email-timestream': str(email_timestream)
            }
        )

        logger.info(f"Successfully uploaded message to S3: s3://{S3_BUCKET_NAME}/{s3_key}")

        # Delete message from queue
        sqs_client.delete_message(
            QueueUrl=SQS_QUEUE_URL,
            ReceiptHandle=message['ReceiptHandle']
        )

        logger.info(f"Deleted message from queue: {message['MessageId']}")
        return True

    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse message body as JSON: {e}")
        return False
    except ClientError as e:
        logger.error(f"AWS error processing message: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error processing message: {e}")
        return False


def poll_and_process():
    """
    Poll SQS queue for messages and process them.

    Returns:
        int: Number of messages processed
    """
    try:
        # Receive messages from SQS
        response = sqs_client.receive_message(
            QueueUrl=SQS_QUEUE_URL,
            MaxNumberOfMessages=MAX_MESSAGES,
            WaitTimeSeconds=20,  # Long polling
            AttributeNames=['All']
        )

        messages = response.get('Messages', [])

        if not messages:
            logger.debug("No messages available in queue")
            return 0

        logger.info(f"Received {len(messages)} message(s) from queue")

        # Process each message
        processed_count = 0
        for message in messages:
            if process_message(message):
                processed_count += 1

        logger.info(f"Successfully processed {processed_count}/{len(messages)} messages")
        return processed_count

    except ClientError as e:
        logger.error(f"Failed to receive messages from SQS: {e}")
        return 0
    except Exception as e:
        logger.error(f"Unexpected error during polling: {e}")
        return 0


def main():
    """Main service loop."""
    logger.info("Starting Service2...")
    logger.info(f"SQS Queue URL: {SQS_QUEUE_URL}")
    logger.info(f"S3 Bucket: {S3_BUCKET_NAME}")
    logger.info(f"Poll Interval: {POLL_INTERVAL} seconds")
    logger.info(f"Max Messages per Poll: {MAX_MESSAGES}")

    # Validate required environment variables
    if not SQS_QUEUE_URL:
        logger.error("SQS_QUEUE_URL environment variable is required")
        exit(1)

    if not S3_BUCKET_NAME:
        logger.error("S3_BUCKET_NAME environment variable is required")
        exit(1)

    # Verify S3 bucket access
    try:
        s3_client.head_bucket(Bucket=S3_BUCKET_NAME)
        logger.info(f"Successfully verified access to S3 bucket: {S3_BUCKET_NAME}")
    except ClientError as e:
        logger.error(f"Cannot access S3 bucket {S3_BUCKET_NAME}: {e}")
        exit(1)

    # Main processing loop
    logger.info("Service2 is running. Press Ctrl+C to stop.")

    while True:
        try:
            poll_and_process()
            time.sleep(POLL_INTERVAL)
        except KeyboardInterrupt:
            logger.info("Received shutdown signal. Stopping service...")
            break
        except Exception as e:
            logger.error(f"Error in main loop: {e}")
            time.sleep(POLL_INTERVAL)


if __name__ == '__main__':
    main()
