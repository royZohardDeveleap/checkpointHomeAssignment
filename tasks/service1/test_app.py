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
            'email': 'test@example.com',
            'subject': 'Test Subject',
            'body': 'Test email body content',
            'timestamp': '2025-01-15T10:30:00Z'
        }
    }


class TestValidatePayload:
    """Test cases for validate_payload function."""

    def test_valid_payload(self, valid_payload):
        """Test validation with a valid payload."""
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is True
        assert error_message is None

    def test_missing_token(self, valid_payload):
        """Test validation when token is missing."""
        del valid_payload['token']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field: token'

    def test_missing_data(self, valid_payload):
        """Test validation when data field is missing."""
        del valid_payload['data']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field: data'

    def test_missing_email(self, valid_payload):
        """Test validation when email is missing from data."""
        del valid_payload['data']['email']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field in data: email'

    def test_missing_subject(self, valid_payload):
        """Test validation when subject is missing from data."""
        del valid_payload['data']['subject']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field in data: subject'

    def test_missing_body(self, valid_payload):
        """Test validation when body is missing from data."""
        del valid_payload['data']['body']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field in data: body'

    def test_missing_timestamp(self, valid_payload):
        """Test validation when timestamp is missing from data."""
        del valid_payload['data']['timestamp']
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field in data: timestamp'

    def test_data_not_dict(self, valid_payload):
        """Test validation when data is not a dictionary."""
        valid_payload['data'] = 'not a dict'
        is_valid, error_message = validate_payload(valid_payload)
        assert is_valid is False
        assert error_message == 'Missing required field: data'


class TestPublishToSQS:
    """Test cases for publish_to_sqs function."""

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
        assert call_args[1]['QueueUrl'] is not None
        assert json.loads(call_args[1]['MessageBody']) == valid_payload['data']

    @patch('app.sqs_client')
    def test_publish_failure(self, mock_sqs_client, valid_payload):
        """Test handling of SQS publish failure."""
        mock_sqs_client.send_message.side_effect = Exception('SQS Error')

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
        assert data['service'] == 'service1'


class TestProcessEndpoint:
    """Test cases for /process endpoint."""

    @patch('app.ssm_client')
    @patch('app.publish_to_sqs')
    def test_successful_process(self, mock_publish, mock_ssm_client, client, valid_payload):
        """Test successful request processing."""
        mock_ssm_client.get_parameter.return_value = {
            'Parameter': {'Value': 'test-token-123'}
        }
        mock_publish.return_value = True

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'success'
        assert 'message_id' in data

    @patch('app.ssm_client')
    def test_invalid_token(self, mock_ssm_client, client, valid_payload):
        """Test request with invalid token."""
        mock_ssm_client.get_parameter.return_value = {
            'Parameter': {'Value': 'correct-token'}
        }
        valid_payload['token'] = 'wrong-token'

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 401
        data = json.loads(response.data)
        assert data['error'] == 'Invalid token'

    def test_missing_payload(self, client):
        """Test request without JSON payload."""
        response = client.post('/process',
                              data='not json',
                              content_type='text/plain')

        assert response.status_code == 400
        data = json.loads(response.data)
        assert data['error'] == 'Invalid JSON payload'

    @patch('app.ssm_client')
    def test_missing_required_field(self, mock_ssm_client, client, valid_payload):
        """Test request with missing required field."""
        mock_ssm_client.get_parameter.return_value = {
            'Parameter': {'Value': 'test-token-123'}
        }
        del valid_payload['data']['email']

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 400
        data = json.loads(response.data)
        assert 'Missing required field' in data['error']

    @patch('app.ssm_client')
    @patch('app.publish_to_sqs')
    def test_sqs_publish_failure(self, mock_publish, mock_ssm_client, client, valid_payload):
        """Test handling of SQS publish failure."""
        mock_ssm_client.get_parameter.return_value = {
            'Parameter': {'Value': 'test-token-123'}
        }
        mock_publish.return_value = False

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 500
        data = json.loads(response.data)
        assert data['error'] == 'Failed to publish message to queue'

    @patch('app.ssm_client')
    def test_ssm_parameter_fetch_failure(self, mock_ssm_client, client, valid_payload):
        """Test handling of SSM parameter fetch failure."""
        mock_ssm_client.get_parameter.side_effect = Exception('SSM Error')

        response = client.post('/process',
                              data=json.dumps(valid_payload),
                              content_type='application/json')

        assert response.status_code == 500
        data = json.loads(response.data)
        assert 'error' in data

    def test_get_method_not_allowed(self, client):
        """Test that GET method is not allowed on /process endpoint."""
        response = client.get('/process')

        assert response.status_code == 405
