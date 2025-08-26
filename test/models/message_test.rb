require "test_helper"
require "ostruct"

class MessageTest < ActiveSupport::TestCase
  # Tests for message_id uniqueness constraint - allows same email across
  # different topics but prevents duplicates within same topic.
  # This handles the case where multiple accounts receive the same email.
  # (emails are unique, but multiple accounts can get the same email)

  test "allows the same message_id in different topics" do
    # Same email can be received by different accounts in different topics
    topic1 = topics(:acc1_topic1)
    topic2 = topics(:acc2_topic1)
    message_id = "unique@example.com"

    message1 = Message.create!(topic: topic1, message_id: message_id, subject: "Test!")
    message2 = Message.create!(topic: topic2, message_id: message_id, subject: "Test!")

    assert message1.persisted?
    assert message2.persisted?
    assert_not_equal message1.id, message2.id
  end

  test "prevents duplicate message_id within the same topic" do
    # Same email should never appear twice in the same conversation
    topic = topics(:acc1_topic1)
    message_id = "unique@example.com"

    Message.create!(topic: topic, message_id: message_id, subject: "Test")

    assert_raises ActiveRecord::RecordNotUnique do
      Message.create!(topic: topic, message_id: message_id, subject: "Test")
    end
  end

  test "WIP: extract_parts handles nil body data" do
    topic = topics(:acc1_topic1)

    gmail_message = OpenStruct.new(
      id: "test-id-123",
      internal_date: 1234567898765,
      snippet: "",
      label_ids: ["UNREAD", "CATEGORY_UPDATES", "SPAM"],
      payload: OpenStruct.new(
        body: OpenStruct.new(size: 0),
        filename: "",
        headers: [
          OpenStruct.new(name: "date", value: "Wed, 20 Aug 2025 15:46:50 +0000"),
          OpenStruct.new(name: "from", value: "Test Sender <sender@example.com>"),
          OpenStruct.new(name: "to", value: "recipient@example.com"),
          OpenStruct.new(name: "subject", value: "Test Subject"),
          OpenStruct.new(name: "message-id", value: "<test-message-id@example.com>"),
          OpenStruct.new(name: "Content-Type", value: "multipart/mixed; boundary=\"===============1108431515942779432==\""),
          OpenStruct.new(name: "MIME-Version", value: "1.0")
        ],
        mime_type: "multipart/mixed",
        part_id: "",
        parts: [
          OpenStruct.new(
            body: OpenStruct.new(size: 0),
            filename: "",
            headers: [
              OpenStruct.new(name: "Content-Type", value: "multipart/alternative; boundary=\"===============0499628116969395543==\""),
              OpenStruct.new(name: "MIME-Version", value: "1.0")
            ],
            mime_type: "multipart/alternative",
            part_id: "0",
            parts: [
              OpenStruct.new(
                body: OpenStruct.new(
                  data: "Plain text content",
                  size: 70
                ),
                filename: "",
                headers: [
                  OpenStruct.new(name: "Content-Type", value: "text/plain; charset=\"utf-8\""),
                  OpenStruct.new(name: "MIME-Version", value: "1.0")
                ],
                mime_type: "text/plain",
                part_id: "0.0"
              ),
              OpenStruct.new(
                body: OpenStruct.new(size: 0),  # No data field at all
                filename: "",
                headers: [
                  OpenStruct.new(name: "Content-Type", value: "multipart/relative; boundary=\"===============8237137818363249141==\""),
                  OpenStruct.new(name: "MIME-Version", value: "1.0")
                ],
                mime_type: "multipart/relative",
                part_id: "0.1",
                parts: [
                  OpenStruct.new(
                    body: OpenStruct.new(
                      data: "<html><body>HTML content</body></html>",
                      size: 275
                    ),
                    filename: "",
                    headers: [
                      OpenStruct.new(name: "Content-Type", value: "text/html; charset=\"utf-8\""),
                      OpenStruct.new(name: "MIME-Version", value: "1.0")
                    ],
                    mime_type: "text/html",
                    part_id: "0.1.0"
                  ),
                  OpenStruct.new(
                    body: OpenStruct.new(
                      attachment_id: "test-attachment-id",
                      size: 9267
                    ),  # No data field
                    filename: "test-image.png",
                    headers: [
                      OpenStruct.new(name: "Content-Type", value: "image/png"),
                      OpenStruct.new(name: "Content-Disposition", value: "inline; filename=\"test-image.png\""),
                      OpenStruct.new(name: "Content-ID", value: "<test-content-id>")
                    ],
                    mime_type: "image/png",
                    part_id: "0.1.1"
                  )
                ]
              )
            ]
          ),
          OpenStruct.new(
            body: OpenStruct.new(
              attachment_id: "test-attachment-id-2",
              size: 8850
            ),  # No data field
            filename: "Test_Agreement",
            headers: [
              OpenStruct.new(name: "Content-Type", value: "text/html"),
              OpenStruct.new(name: "Content-Disposition", value: "attachment; filename=\"Test_Agreement\"")
            ],
            mime_type: "text/html",
            part_id: "1"
          )
        ]
      )
    )

    # Should not raise NoMethodError when body.data is nil
    assert_nothing_raised do
      Message.cache_from_gmail(topic, gmail_message)
    end
  end
end
