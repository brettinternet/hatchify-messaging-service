#!/bin/bash

# Extended test script for messaging service endpoints
# This script provides comprehensive testing of the messaging service with edge cases and scenarios

BASE_URL="http://localhost:${SERVER_PORT:-8080}"
CONTENT_TYPE="Content-Type: application/json"
FAILED_TESTS=0
TOTAL_TESTS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Extended Messaging Service Integration Tests ==="
echo "Base URL: $BASE_URL"
echo

# Helper function to run a test and check status
run_test() {
    local test_name="$1"
    local expected_status="$2"
    local curl_cmd="$3"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "${BLUE}Test $TOTAL_TESTS: $test_name${NC}"

    local response=$(eval "$curl_cmd" 2>/dev/null)
    local actual_status=$(echo "$response" | grep -o "Status: [0-9]*" | grep -o "[0-9]*")

    if [ "$actual_status" = "$expected_status" ]; then
        echo -e "${GREEN} PASS - Expected status $expected_status${NC}"
    else
        echo -e "${RED} FAIL - Expected status $expected_status, got $actual_status${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo
}

# Basic SMS send
run_test "Send SMS message" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Hello! This is a test SMS message.\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Basic MMS send
run_test "Send MMS message with attachment" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"mms\",
    \"body\": \"MMS with image\",
    \"attachments\": [\"https://example.com/image.jpg\"],
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Basic Email send
run_test "Send Email message" "204" "curl -s -X POST '$BASE_URL/api/messages/email' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"user@usehatchapp.com\",
    \"to\": \"contact@gmail.com\",
    \"body\": \"Hello! This is a test email.\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Missing required fields
run_test "Missing 'from' field" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Missing from field\"
  }' \
  -w 'Status: %{http_code}'"

run_test "Missing 'to' field" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"type\": \"sms\",
    \"body\": \"Missing to field\"
  }' \
  -w 'Status: %{http_code}'"

run_test "Missing 'body' field" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\"
  }' \
  -w 'Status: %{http_code}'"

# Invalid JSON
run_test "Invalid JSON format" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d 'invalid json {' \
  -w 'Status: %{http_code}'"

# Empty body
run_test "Empty request body" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '' \
  -w 'Status: %{http_code}'"

# Null from field
run_test "Null 'from' field" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": null,
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Null from field\"
  }' \
  -w 'Status: %{http_code}'"

# International phone numbers
run_test "International phone numbers" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+441234567890\",
    \"to\": \"+33123456789\",
    \"type\": \"sms\",
    \"body\": \"International SMS test\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Long message body
run_test "Long message body" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"This is a very long message that exceeds the typical SMS length limit to test how the system handles longer text content in messaging scenarios.\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# MMS with multiple attachments
run_test "MMS with multiple attachments" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"mms\",
    \"body\": \"Multiple attachments\",
    \"attachments\": [\"https://example.com/image1.jpg\", \"https://example.com/image2.png\", \"https://example.com/doc.pdf\"],
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Email with HTML content
run_test "Email with HTML content" "204" "curl -s -X POST '$BASE_URL/api/messages/email' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"user@usehatchapp.com\",
    \"to\": \"contact@gmail.com\",
    \"body\": \"<html><body><h1>Hello!</h1><p>This is an <b>HTML</b> email with <a href=\\\"https://example.com\\\">links</a>.</p></body></html>\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Incoming SMS webhook
run_test "Incoming SMS webhook" "200" "curl -s -X POST '$BASE_URL/api/webhooks/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+18045551234\",
    \"to\": \"+12016661234\",
    \"type\": \"sms\",
    \"messaging_provider_id\": \"msg_incoming_1\",
    \"body\": \"Incoming SMS message\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Incoming MMS webhook
run_test "Incoming MMS webhook" "200" "curl -s -X POST '$BASE_URL/api/webhooks/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+18045551234\",
    \"to\": \"+12016661234\",
    \"type\": \"mms\",
    \"messaging_provider_id\": \"msg_incoming_2\",
    \"body\": \"Incoming MMS with photo\",
    \"attachments\": [\"https://provider.com/media/photo.jpg\"],
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Incoming Email webhook
run_test "Incoming Email webhook" "200" "curl -s -X POST '$BASE_URL/api/webhooks/email' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"contact@gmail.com\",
    \"to\": \"user@usehatchapp.com\",
    \"xillio_id\": \"email_incoming_1\",
    \"body\": \"<p>Incoming HTML email</p>\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Different timestamp formats
run_test "ISO timestamp with timezone" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Timezone test\",
    \"timestamp\": \"2024-11-01T14:00:00-05:00\"
  }' \
  -w 'Status: %{http_code}'"

# Message without timestamp (should default to current time)
run_test "Message without timestamp" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"No timestamp provided\"
  }' \
  -w 'Status: %{http_code}'"

# Email with markdown-style addresses
run_test "Email with markdown addresses" "200" "curl -s -X POST '$BASE_URL/api/webhooks/email' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"[John Doe](mailto:john@example.com)\",
    \"to\": \"[Jane Smith](mailto:jane@company.com)\",
    \"xillio_id\": \"email_markdown_1\",
    \"body\": \"Email with formatted addresses\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Empty attachments array
run_test "Empty attachments array" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"mms\",
    \"body\": \"MMS with empty attachments\",
    \"attachments\": [],
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Rate limiting test (should pass first, then get rate limited)
run_test "First message (should pass)" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+15551234567\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Rate limit test 1\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Same sender immediately (might get rate limited)
run_test "Same sender rapid fire" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+15551234567\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Rate limit test 2\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Get conversations list
run_test "Get conversations list" "200" "curl -s -X GET '$BASE_URL/api/conversations' -w 'Status: %{http_code}'"

# Get conversations with from filter
run_test "Get conversations filtered by from" "200" "curl -s -X GET '$BASE_URL/api/conversations?from=%2B12016661234' -w 'Status: %{http_code}'"

# Get conversations with to filter
run_test "Get conversations filtered by to" "200" "curl -s -X GET '$BASE_URL/api/conversations?to=%2B18045551234' -w 'Status: %{http_code}'"

# Get conversations with limit
run_test "Get conversations with limit" "200" "curl -s -X GET '$BASE_URL/api/conversations?limit=5' -w 'Status: %{http_code}'"

# Invalid conversation messages endpoint
run_test "Get messages for invalid conversation" "200" "curl -s -X GET '$BASE_URL/api/conversations/nonexistent/messages' -w 'Status: %{http_code}'"

# Unicode content in SMS
run_test "SMS with Unicode content" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"sms\",
    \"body\": \"Hello! < Unicode test with emojis 😎
 and special chars: ��������\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Very large email body
run_test "Email with large body" "204" "curl -s -X POST '$BASE_URL/api/messages/email' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"sender@example.com\",
    \"to\": \"recipient@example.com\",
    \"body\": \"'$(printf 'This is a large email body content. %.0s' {1..100})'\"
  }' \
  -w 'Status: %{http_code}'"

# Multiple conversations setup
echo -e "${YELLOW}Setting up multiple conversation scenarios...${NC}"

# Create messages between different participants to test conversation grouping
run_test "Message A->B" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+11111111111\",
    \"to\": \"+22222222222\",
    \"type\": \"sms\",
    \"body\": \"Message from A to B\",
    \"timestamp\": \"2024-11-01T14:00:00Z\"
  }' \
  -w 'Status: %{http_code}'"

run_test "Message B->A" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+22222222222\",
    \"to\": \"+11111111111\",
    \"type\": \"sms\",
    \"body\": \"Reply from B to A\",
    \"timestamp\": \"2024-11-01T14:01:00Z\"
  }' \
  -w 'Status: %{http_code}'"

run_test "Message C->D" "204" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+33333333333\",
    \"to\": \"+44444444444\",
    \"type\": \"sms\",
    \"body\": \"Different conversation\",
    \"timestamp\": \"2024-11-01T14:02:00Z\"
  }' \
  -w 'Status: %{http_code}'"

# Edge cases for message types
run_test "Invalid message type" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"invalid_type\",
    \"body\": \"Invalid message type\"
  }' \
  -w 'Status: %{http_code}'"

# Missing message type
run_test "Missing message type" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"body\": \"Missing type field\"
  }' \
  -w 'Status: %{http_code}'"

# Non-string attachment - TODO: how to handle?
run_test "Invalid attachment format" "400" "curl -s -X POST '$BASE_URL/api/messages/sms' \
  -H '$CONTENT_TYPE' \
  -d '{
    \"from\": \"+12016661234\",
    \"to\": \"+18045551234\",
    \"type\": \"mms\",
    \"body\": \"Invalid attachment\",
    \"attachments\": \"not_an_array\"
  }' \
  -w 'Status: %{http_code}'"

# Summary
echo "=== Test Summary ==="
echo -e "Total tests: $TOTAL_TESTS"
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ${NC}"
    exit 0
else
    echo -e "${RED}Failed tests: $FAILED_TESTS${NC}"
    echo -e "${YELLOW}Passed tests: $((TOTAL_TESTS - FAILED_TESTS))${NC}"
    exit 1
fi
