import os
import json
import logging
from flask import Flask, request, jsonify
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# AWS clients
ssm_client = boto3.client('ssm', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
sqs_client = boto3.client('sqs', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Environment variables
SQS_QUEUE_URL = os.environ.get('SQS_QUEUE_URL')
TOKEN_PARAMETER_NAME = os.environ.get('TOKEN_PARAMETER_NAME', '/ha-roy-develeap/dev/service1/auth-token')

# Cache for token
_cached_token = None


def get_auth_token():
    """Retrieve authentication token from SSM Parameter Store."""
    global _cached_token

    if _cached_token:
        return _cached_token

    try:
        response = ssm_client.get_parameter(
            Name=TOKEN_PARAMETER_NAME,
            WithDecryption=True
        )
        _cached_token = response['Parameter']['Value']
        logger.info(f"Successfully retrieved token from SSM: {TOKEN_PARAMETER_NAME}")
        return _cached_token
    except ClientError as e:
        logger.error(f"Failed to retrieve token from SSM: {e}")
        raise


def validate_payload(payload):
    """
    Validate the request payload.

    Args:
        payload: The request JSON payload

    Returns:
        tuple: (is_valid, error_message)
    """
    # Check if payload has required top-level keys
    if 'data' not in payload:
        return False, "Missing 'data' field"

    if 'token' not in payload:
        return False, "Missing 'token' field"

    # Validate token
    try:
        expected_token = get_auth_token()
        if payload['token'] != expected_token:
            return False, "Invalid token"
    except Exception as e:
        logger.error(f"Token validation error: {e}")
        return False, "Token validation failed"

    # Validate data has all 4 required fields
    data = payload['data']
    required_fields = ['email_subject', 'email_sender', 'email_timestream', 'email_content']

    missing_fields = [field for field in required_fields if field not in data]
    if missing_fields:
        return False, f"Missing required fields in data: {', '.join(missing_fields)}"

    # Validate that fields are not empty
    empty_fields = [field for field in required_fields if not data[field]]
    if empty_fields:
        return False, f"Empty values for fields: {', '.join(empty_fields)}"

    return True, None


def publish_to_sqs(message_data):
    """
    Publish message to SQS queue.

    Args:
        message_data: The data to publish

    Returns:
        bool: True if successful, False otherwise
    """
    try:
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message_data)
        )
        logger.info(f"Message published to SQS. MessageId: {response['MessageId']}")
        return True
    except ClientError as e:
        logger.error(f"Failed to publish to SQS: {e}")
        return False


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy'}), 200


@app.route('/process', methods=['POST'])
def process_email():
    """
    Process incoming email data.

    Expected payload:
    {
        "data": {
            "email_subject": "...",
            "email_sender": "...",
            "email_timestream": "...",
            "email_content": "..."
        },
        "token": "..."
    }
    """
    try:
        # Get JSON payload
        payload = request.get_json()
        if not payload:
            return jsonify({'error': 'Invalid JSON payload'}), 400

        logger.info(f"Received request: {json.dumps(payload, default=str)}")

        # Validate payload
        is_valid, error_message = validate_payload(payload)
        if not is_valid:
            logger.warning(f"Validation failed: {error_message}")
            return jsonify({'error': error_message}), 400

        # Publish to SQS
        if not publish_to_sqs(payload['data']):
            return jsonify({'error': 'Failed to publish message to queue'}), 500

        return jsonify({
            'status': 'success',
            'message': 'Email data processed and queued successfully'
        }), 200

    except Exception as e:
        logger.error(f"Error processing request: {e}")
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/', methods=['GET'])
def root():
    """Root endpoint."""
    return jsonify({
        'service': 'service1',
        'version': '1.0.0',
        'endpoints': {
            'health': '/health',
            'process': '/process (POST)'
        }
    }), 200


if __name__ == '__main__':
    # Validate required environment variables
    if not SQS_QUEUE_URL:
        logger.error("SQS_QUEUE_URL environment variable is required")
        exit(1)

    logger.info(f"Starting Service1...")
    logger.info(f"SQS Queue URL: {SQS_QUEUE_URL}")
    logger.info(f"Token Parameter: {TOKEN_PARAMETER_NAME}")

    # Run Flask app
    app.run(host='0.0.0.0', port=8080, debug=False)
