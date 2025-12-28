import pytest
import json
import os
from unittest.mock import patch, MagicMock, call
from datetime import datetime
from app import (
    generate_s3_key,
    upload_to_s3,
    process_message,
    poll_and_process
)


@pytest.fixture
def sample_message():
    """Return a sample SQS message."""
    return {
        'email': 'test@example.com',
        'subject': 'Test Subject',
        'body': 'Test email body content',
        'timestamp': '2025-01-15T10:30:00Z'
    }


@pytest.fixture
def sqs_message_response():
    """Return a sample SQS receive_message response."""
    return {
        'Messages': [
            {
                'MessageId': 'msg-1',
                'ReceiptHandle': 'receipt-1',
                'Body': json.dumps({
                    'email': 'test1@example.com',
                    'subject': 'Subject 1',
                    'body': 'Body 1',
                    'timestamp': '2025-01-15T10:30:00Z'
                })
            },
            {
                'MessageId': 'msg-2',
                'ReceiptHandle': 'receipt-2',
                'Body': json.dumps({
                    'email': 'test2@example.com',
                    'subject': 'Subject 2',
                    'body': 'Body 2',
                    'timestamp': '2025-01-15T11:45:00Z'
                })
            }
        ]
    }


class TestGenerateS3Key:
    """Test cases for generate_s3_key function."""

    def test_generate_s3_key_valid_timestamp(self, sample_message):
        """Test S3 key generation with valid timestamp."""
        key = generate_s3_key(sample_message)

        assert key.startswith('emails/2025/01/15/10/')
        assert key.endswith('_Test_Subject.json')
        assert 'emails/2025/01/15/10/' in key

    def test_generate_s3_key_with_special_chars_in_subject(self):
        """Test S3 key generation with special characters in subject."""
        message = {
            'email': 'test@example.com',
            'subject': 'Test/Subject:With*Special?Chars',
            'body': 'Test body',
            'timestamp': '2025-01-15T10:30:00Z'
        }

        key = generate_s3_key(message)

        assert '/' not in key.split('/')[-1]
        assert ':' not in key.split('/')[-1]
        assert '*' not in key.split('/')[-1]
        assert '?' not in key.split('/')[-1]

    def test_generate_s3_key_with_long_subject(self):
        """Test S3 key generation with very long subject."""
        long_subject = 'A' * 200
        message = {
            'email': 'test@example.com',
            'subject': long_subject,
            'body': 'Test body',
            'timestamp': '2025-01-15T10:30:00Z'
        }

        key = generate_s3_key(message)

        filename = key.split('/')[-1]
        assert len(filename) <= 255

    def test_generate_s3_key_different_timestamps(self):
        """Test S3 key generation with different timestamps creates different paths."""
        message1 = {
            'email': 'test@example.com',
            'subject': 'Test',
            'body': 'Test body',
            'timestamp': '2025-01-15T10:30:00Z'
        }
        message2 = {
            'email': 'test@example.com',
            'subject': 'Test',
            'body': 'Test body',
            'timestamp': '2025-02-20T15:45:00Z'
        }

        key1 = generate_s3_key(message1)
        key2 = generate_s3_key(message2)

        assert 'emails/2025/01/15/10/' in key1
        assert 'emails/2025/02/20/15/' in key2
        assert key1 != key2


class TestUploadToS3:
    """Test cases for upload_to_s3 function."""

    @patch.dict(os.environ, {'S3_BUCKET_NAME': 'test-bucket'})
    @patch('app.s3_client')
    def test_successful_upload(self, mock_s3_client, sample_message):
        """Test successful upload to S3."""
        mock_s3_client.put_object.return_value = {
            'ResponseMetadata': {'HTTPStatusCode': 200}
        }

        result = upload_to_s3(sample_message)

        assert result is True
        mock_s3_client.put_object.assert_called_once()
        call_args = mock_s3_client.put_object.call_args
        assert call_args[1]['Bucket'] == 'test-bucket'
        assert 'emails/' in call_args[1]['Key']
        assert json.loads(call_args[1]['Body']) == sample_message

    @patch.dict(os.environ, {'S3_BUCKET_NAME': 'test-bucket'})
    @patch('app.s3_client')
    def test_upload_failure(self, mock_s3_client, sample_message):
        """Test handling of S3 upload failure."""
        mock_s3_client.put_object.side_effect = Exception('S3 Error')

        result = upload_to_s3(sample_message)

        assert result is False

    @patch.dict(os.environ, {'S3_BUCKET_NAME': 'test-bucket'})
    @patch('app.s3_client')
    def test_upload_json_formatting(self, mock_s3_client, sample_message):
        """Test that uploaded JSON is properly formatted."""
        mock_s3_client.put_object.return_value = {
            'ResponseMetadata': {'HTTPStatusCode': 200}
        }

        upload_to_s3(sample_message)

        call_args = mock_s3_client.put_object.call_args
        uploaded_json = call_args[1]['Body']

        parsed = json.loads(uploaded_json)
        assert parsed == sample_message
        assert '\n' in uploaded_json


class TestProcessMessage:
    """Test cases for process_message function."""

    @patch('app.upload_to_s3')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_successful_message_processing(self, mock_sqs_client, mock_upload, sample_message):
        """Test successful processing of a message."""
        mock_upload.return_value = True
        message = {
            'MessageId': 'test-msg-id',
            'ReceiptHandle': 'test-receipt',
            'Body': json.dumps(sample_message)
        }

        process_message(message)

        mock_upload.assert_called_once_with(sample_message)
        mock_sqs_client.delete_message.assert_called_once_with(
            QueueUrl='https://sqs.us-east-1.amazonaws.com/123456789012/test-queue',
            ReceiptHandle='test-receipt'
        )

    @patch('app.upload_to_s3')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_upload_failure_no_delete(self, mock_sqs_client, mock_upload, sample_message):
        """Test that message is not deleted if upload fails."""
        mock_upload.return_value = False
        message = {
            'MessageId': 'test-msg-id',
            'ReceiptHandle': 'test-receipt',
            'Body': json.dumps(sample_message)
        }

        process_message(message)

        mock_upload.assert_called_once_with(sample_message)
        mock_sqs_client.delete_message.assert_not_called()

    @patch('app.upload_to_s3')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_invalid_json_in_message(self, mock_sqs_client, mock_upload):
        """Test handling of invalid JSON in message body."""
        message = {
            'MessageId': 'test-msg-id',
            'ReceiptHandle': 'test-receipt',
            'Body': 'invalid json'
        }

        process_message(message)

        mock_upload.assert_not_called()
        mock_sqs_client.delete_message.assert_not_called()

    @patch('app.upload_to_s3')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_delete_message_failure(self, mock_sqs_client, mock_upload, sample_message):
        """Test handling of delete message failure."""
        mock_upload.return_value = True
        mock_sqs_client.delete_message.side_effect = Exception('Delete Error')
        message = {
            'MessageId': 'test-msg-id',
            'ReceiptHandle': 'test-receipt',
            'Body': json.dumps(sample_message)
        }

        process_message(message)

        mock_upload.assert_called_once()


class TestPollAndProcess:
    """Test cases for poll_and_process function."""

    @patch('app.process_message')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_successful_polling_with_messages(self, mock_sqs_client, mock_process, sqs_message_response):
        """Test successful polling with messages."""
        mock_sqs_client.receive_message.return_value = sqs_message_response

        poll_and_process()

        mock_sqs_client.receive_message.assert_called_once_with(
            QueueUrl='https://sqs.us-east-1.amazonaws.com/123456789012/test-queue',
            MaxNumberOfMessages=10,
            WaitTimeSeconds=20
        )
        assert mock_process.call_count == 2

    @patch('app.process_message')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_polling_with_no_messages(self, mock_sqs_client, mock_process):
        """Test polling when no messages are available."""
        mock_sqs_client.receive_message.return_value = {}

        poll_and_process()

        mock_sqs_client.receive_message.assert_called_once()
        mock_process.assert_not_called()

    @patch('app.process_message')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_polling_failure(self, mock_sqs_client, mock_process):
        """Test handling of polling failure."""
        mock_sqs_client.receive_message.side_effect = Exception('SQS Error')

        poll_and_process()

        mock_sqs_client.receive_message.assert_called_once()
        mock_process.assert_not_called()

    @patch('app.process_message')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_process_message_exception_handling(self, mock_sqs_client, mock_process, sqs_message_response):
        """Test that poll_and_process continues even if process_message fails."""
        mock_sqs_client.receive_message.return_value = sqs_message_response
        mock_process.side_effect = [Exception('Process Error'), None]

        poll_and_process()

        assert mock_process.call_count == 2

    @patch('app.process_message')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_polling_uses_long_polling(self, mock_sqs_client, mock_process):
        """Test that long polling is configured correctly."""
        mock_sqs_client.receive_message.return_value = {}

        poll_and_process()

        call_args = mock_sqs_client.receive_message.call_args
        assert call_args[1]['WaitTimeSeconds'] == 20

    @patch('app.process_message')
    @patch('app.sqs_client')
    @patch.dict(os.environ, {'SQS_QUEUE_URL': 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'})
    def test_polling_max_messages(self, mock_sqs_client, mock_process):
        """Test that max messages is set correctly."""
        mock_sqs_client.receive_message.return_value = {}

        poll_and_process()

        call_args = mock_sqs_client.receive_message.call_args
        assert call_args[1]['MaxNumberOfMessages'] == 10
