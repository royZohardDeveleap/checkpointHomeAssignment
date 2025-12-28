import pytest
import json
from unittest.mock import patch, MagicMock
from app import app, validate_payload, publish_to_sqs


@pytest.fixture
def client():
    """Create a test client for the Flask app."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


@pytest.fixture
def valid_payload():
    """Return a valid test payload."""
    return {
        'token': 'test-token-123',
        'data': {
            'email_subject': 'Happy new year!',
            'email_sender': 'John Doe',
            'email_timestream': '1735392000',
            'email_content': 'Just want to say... Happy new year!!!'
        }
    }


class TestValidatePayload:
    """Test cases for validate_payload function."""

    @patch('app.get_auth_token')
    def test_valid_payload(self, mock_get_token, valid_payload):
        """Test validation with a valid payload."""
        mock_get_token.return_value = 'test-token-123'
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is True
        assert error_message is None

    def test_missing_token(self, valid_payload):
        """Test validation when token is missing."""
        del valid_payload['token']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == "Missing 'token' field"

    def test_missing_data(self, valid_payload):
        """Test validation when data field is missing."""
        del valid_payload['data']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == "Missing 'data' field"

    @patch('app.get_auth_token')
    def test_missing_email_subject(self, mock_get_token, valid_payload):
        """Test validation when email_subject is missing from data."""
        mock_get_token.return_value = 'test-token-123'
        del valid_payload['data']['email_subject']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert 'email_subject' in error_message

    @patch('app.get_auth_token')
    def test_missing_email_sender(self, mock_get_token, valid_payload):
        """Test validation when email_sender is missing from data."""
        mock_get_token.return_value = 'test-token-123'
        del valid_payload['data']['email_sender']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert 'email_sender' in error_message

    @patch('app.get_auth_token')
    def test_missing_email_timestream(self, mock_get_token, valid_payload):
        """Test validation when email_timestream is missing from data."""
        mock_get_token.return_value = 'test-token-123'
        del valid_payload['data']['email_timestream']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert 'email_timestream' in error_message

    @patch('app.get_auth_token')
    def test_missing_email_content(self, mock_get_token, valid_payload):
        """Test validation when email_content is missing from data."""
        mock_get_token.return_value = 'test-token-123'
        del valid_payload['data']['email_content']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert 'email_content' in error_message

    @patch('app.get_auth_token')
    def test_empty_field(self, mock_get_token, valid_payload):
        """Test validation when a field is empty."""
        mock_get_token.return_value = 'test-token-123'
        valid_payload['data']['email_subject'] = ''
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert 'Empty values' in error_message

    @patch('app.get_auth_token')
    def test_invalid_token(self, mock_get_token, valid_payload):
        """Test validation with invalid token."""
        mock_get_token.return_value = 'correct-token'
        valid_payload['token'] = 'wrong-token'
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Invalid token'


class TestPublishToSQS:
    """Test cases for publish_to_sqs function."""

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.sqs_client')
    def test_successful_publish(self, mock_sqs_client, valid_payload):
        """Test successful message publishing to SQS."""
        mock_sqs_client.send_message.return_value = {
            'MessageId': 'test-message-id',
            'ResponseMetadata': {'HTTPStatusCode': 200}
        }

        result = publish_to_sqs(valid_payload['data'])

        assert result is True
        mock_sqs_client.send_message.assert_called_once()
        call_args = mock_sqs_client.send_message.call_args
        assert call_args[1]['QueueUrl'] == 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'
        assert json.loads(call_args[1]['MessageBody']) == valid_payload['data']

    @patch('app.sqs_client')
    @patch.dict('os.environ', {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_publish_failure(self, mock_sqs_client, valid_payload):
        """Test handling of SQS publish failure."""
        from botocore.exceptions import ClientError
        mock_sqs_client.send_message.side_effect = ClientError(
            {'Error': {'Code': 'ServiceUnavailable', 'Message': 'Service unavailable'}},
            'SendMessage'
        )

        result = publish_to_sqs(valid_payload['data'])

        assert result is False


class TestHealthEndpoint:
    """Test cases for /health endpoint."""

    def test_health_endpoint(self, client):
        """Test the health check endpoint."""
        response = client.get('/health')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'


class TestRootEndpoint:
    """Test cases for / endpoint."""

    def test_root_endpoint(self, client):
        """Test the root endpoint."""
        response = client.get('/')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['service'] == 'service1'
        assert 'version' in data
        assert 'endpoints' in data


class TestProcessEndpoint:
    """Test cases for /process endpoint."""

    @patch('app.get_auth_token')
    @patch('app.publish_to_sqs')
    def test_successful_process(self, mock_publish, mock_get_token, client, valid_payload):
        """Test successful request processing."""
        mock_get_token.return_value = 'test-token-123'
        mock_publish.return_value = True

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert 'message' in data

    @patch('app.get_auth_token')
    def test_invalid_token(self, mock_get_token, client, valid_payload):
        """Test request with invalid token."""
        mock_get_token.return_value = 'correct-token'
        valid_payload['token'] = 'wrong-token'

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 400
        data = json.loads(response.data)
        assert data['error'] == 'Invalid token'

    def test_missing_payload(self, client):
        """Test request without JSON payload."""
        response = client.post('/process',
                              data='not json',
                              content_type='text/plain')

        # Flask returns 500 when Content-Type is not application/json
        # The actual error is caught in the except block
        assert response.status_code == 500
        data = json.loads(response.data)
        assert 'error' in data

    @patch('app.get_auth_token')
    def test_missing_required_field(self, mock_get_token, client, valid_payload):
        """Test request with missing required field."""
        mock_get_token.return_value = 'test-token-123'
        del valid_payload['data']['email_subject']

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'Missing required fields' in data['error']

    @patch('app.get_auth_token')
    @patch('app.publish_to_sqs')
    def test_sqs_publish_failure(self, mock_publish, mock_get_token, client, valid_payload):
        """Test handling of SQS publish failure."""
        mock_get_token.return_value = 'test-token-123'
        mock_publish.return_value = False

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 500
        data = json.loads(response.data)
        assert data['error'] == 'Failed to publish message to queue'

    @patch('app.get_auth_token')
    def test_get_auth_token_failure(self, mock_get_token, client, valid_payload):
        """Test handling of get_auth_token failure."""
        mock_get_token.side_effect = Exception('SSM Error')

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 400
        data = json.loads(response.data)
        assert data['error'] == 'Token validation failed'

    def test_get_method_not_allowed(self, client):
        """Test that GET method is not allowed on /process endpoint."""
        response = client.get('/process')

        assert response.status_code == 405
