import pytest
import json
from unittest.mock import patch, MagicMock
from botocore.exceptions import ClientError
from app import process_message, poll_and_process


@pytest.fixture
def sqs_message():
    """Return a sample SQS message with the expected format."""
    return {
        'MessageId': 'test-message-id-123',
        'ReceiptHandle': 'test-receipt-handle',
        'Body': json.dumps({
            'email_subject': 'Happy new year!',
            'email_sender': 'John Doe',
            'email_timestream': '1735392000',
            'email_content': 'Just want to say... Happy new year!!!'
        })
    }


@pytest.fixture
def invalid_sqs_message():
    """Return an SQS message with invalid JSON body."""
    return {
        'MessageId': 'test-message-id-456',
        'ReceiptHandle': 'test-receipt-handle-2',
        'Body': 'not valid json'
    }


class TestProcessMessage:
    """Test cases for process_message function."""

    @patch('app.S3_BUCKET_NAME', 'test-bucket')
    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.sqs_client')
    @patch('app.s3_client')
    def test_successful_message_processing(self, mock_s3, mock_sqs, sqs_message):
        """Test successful processing of a valid SQS message."""
        result = process_message(sqs_message)

        assert result is True
        # Verify S3 upload was called
        mock_s3.put_object.assert_called_once()
        call_args = mock_s3.put_object.call_args
        assert call_args[1]['Bucket'] == 'test-bucket'
        assert 'emails/' in call_args[1]['Key']
        assert '.json' in call_args[1]['Key']

        # Verify message was deleted from queue
        mock_sqs.delete_message.assert_called_once()
        assert mock_sqs.delete_message.call_args[1]['ReceiptHandle'] == 'test-receipt-handle'

    @patch('app.S3_BUCKET_NAME', 'test-bucket')
    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    def test_invalid_json_message(self, invalid_sqs_message):
        """Test handling of message with invalid JSON body."""
        result = process_message(invalid_sqs_message)

        assert result is False

    @patch('app.S3_BUCKET_NAME', 'test-bucket')
    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.sqs_client')
    @patch('app.s3_client')
    def test_s3_upload_failure(self, mock_s3, mock_sqs, sqs_message):
        """Test handling of S3 upload failure."""
        mock_s3.put_object.side_effect = ClientError(
            {'Error': {'Code': 'ServiceUnavailable', 'Message': 'Service unavailable'}},
            'PutObject'
        )

        result = process_message(sqs_message)

        assert result is False
        # Message should not be deleted if upload fails
        mock_sqs.delete_message.assert_not_called()

    @patch('app.S3_BUCKET_NAME', 'test-bucket')
    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.sqs_client')
    @patch('app.s3_client')
    def test_sqs_delete_failure(self, mock_s3, mock_sqs, sqs_message):
        """Test handling of SQS delete failure."""
        mock_sqs.delete_message.side_effect = ClientError(
            {'Error': {'Code': 'ReceiptHandleIsInvalid', 'Message': 'Invalid receipt handle'}},
            'DeleteMessage'
        )

        result = process_message(sqs_message)

        # Process should fail if delete fails
        assert result is False
        # But S3 upload should have been attempted
        mock_s3.put_object.assert_called_once()


class TestPollAndProcess:
    """Test cases for poll_and_process function."""

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.MAX_MESSAGES', 10)
    @patch('app.process_message')
    @patch('app.sqs_client')
    def test_successful_polling_with_messages(self, mock_sqs, mock_process, sqs_message):
        """Test successful polling with messages available."""
        mock_sqs.receive_message.return_value = {
            'Messages': [sqs_message, sqs_message]
        }
        mock_process.return_value = True

        result = poll_and_process()

        assert result == 2
        assert mock_process.call_count == 2
        mock_sqs.receive_message.assert_called_once()

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.MAX_MESSAGES', 10)
    @patch('app.sqs_client')
    def test_polling_with_no_messages(self, mock_sqs):
        """Test polling when no messages are available."""
        mock_sqs.receive_message.return_value = {}

        result = poll_and_process()

        assert result == 0

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.MAX_MESSAGES', 10)
    @patch('app.process_message')
    @patch('app.sqs_client')
    def test_partial_processing_failure(self, mock_sqs, mock_process, sqs_message):
        """Test polling when some messages fail to process."""
        mock_sqs.receive_message.return_value = {
            'Messages': [sqs_message, sqs_message, sqs_message]
        }
        # First succeeds, second fails, third succeeds
        mock_process.side_effect = [True, False, True]

        result = poll_and_process()

        assert result == 2  # Only 2 out of 3 processed successfully
        assert mock_process.call_count == 3

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.MAX_MESSAGES', 10)
    @patch('app.sqs_client')
    def test_sqs_receive_failure(self, mock_sqs):
        """Test handling of SQS receive_message failure."""
        mock_sqs.receive_message.side_effect = ClientError(
            {'Error': {'Code': 'ServiceUnavailable', 'Message': 'Service unavailable'}},
            'ReceiveMessage'
        )

        result = poll_and_process()

        assert result == 0

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.MAX_MESSAGES', 10)
    @patch('app.sqs_client')
    def test_unexpected_exception(self, mock_sqs):
        """Test handling of unexpected exceptions."""
        mock_sqs.receive_message.side_effect = Exception('Unexpected error')

        result = poll_and_process()

        assert result == 0

    @patch('app.SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue')
    @patch('app.MAX_MESSAGES', 10)
    @patch('app.sqs_client')
    def test_polling_configuration(self, mock_sqs):
        """Test that polling uses correct configuration."""
        mock_sqs.receive_message.return_value = {}

        poll_and_process()

        call_args = mock_sqs.receive_message.call_args
        assert call_args[1]['QueueUrl'] == 'https://sqs.us-east-1.amazonaws.com/123456789012/test-queue'
        assert call_args[1]['MaxNumberOfMessages'] == 10
        assert call_args[1]['WaitTimeSeconds'] == 20  # Long polling
