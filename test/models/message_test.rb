require "test_helper"
require "ostruct"

class MessageTest < ActiveSupport::TestCase
  def setup
    stub_request(:post, "https://api.voyageai.com/v1/embeddings")
      # .with(body: hash_including({output_dimension: 1024}))
      .to_return_json(body: {data: [{embedding: Array.new(1024, 0)}]})

    stub_request(:post, "https://api.cohere.com/v2/embed")
      # .with(body: hash_including({output_dimension: 1024}))
      .to_return_json(body: {embeddings: {float: [Array.new(1024, 0)]}})
  end

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

  test "handles message with HTML attachments" do
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

  test "handles message without label_ids field" do
    topic = topics(:acc1_topic1)

    gmail_message = OpenStruct.new(
      history_id: 14175304,
      id: "198f620c7272a833",
      internal_date: 1756476000000,
      payload: OpenStruct.new(
        body: OpenStruct.new(size: 0),
        filename: "",
        headers: [
          OpenStruct.new(name: "MIME-Version", value: "1.0"),
          OpenStruct.new(name: "Date", value: "Fri, 29 Aug 2025 09:00:00 -0500"),
          OpenStruct.new(name: "Message-ID", value: "<TEST-MESSAGE-ID-123@mail.example.com>"),
          OpenStruct.new(name: "Subject", value: "Weekly Update"),
          OpenStruct.new(name: "From", value: "Test Sender <test.sender@example.org>"),
          OpenStruct.new(name: "To", value: "Test Group <test-group@example.org>"),
          OpenStruct.new(name: "Content-Type", value: "multipart/alternative; boundary=\"0000000000000a14b6063d46c609\"")
        ],
        mime_type: "multipart/alternative",
        part_id: "",
        parts: [
          OpenStruct.new(
            body: OpenStruct.new(
              data: "This is a test message with plain text content. Here are some updates: - First update item - Second update item - Third update item. Please review and respond if you have any questions.",
              size: 2168
            ),
            filename: "",
            headers: [
              OpenStruct.new(name: "Content-Type", value: "text/plain; charset=\"UTF-8\"")
            ],
            mime_type: "text/plain",
            part_id: "0"
          ),
          OpenStruct.new(
            body: OpenStruct.new(
              data: "<div dir=\"ltr\"><div><font face=\"times new roman, serif\" size=\"4\">This is a test message</font></div><div><font face=\"times new roman, serif\" size=\"4\"><br></font></div><div><font face=\"times new roman, serif\" size=\"4\">Here are some updates:</font></div><div><ul><li><font face=\"times new roman, serif\" size=\"4\">First update item with HTML formatting</font></li><li><font face=\"times new roman, serif\" size=\"4\">Second update item with additional details</font></li><li><font face=\"times new roman, serif\" size=\"4\">Third update item for testing purposes</font></li></ul></div><div><font face=\"times new roman, serif\" size=\"4\">Please review and respond if you have any questions!</font></div></div>",
              size: 6900
            ),
            filename: "",
            headers: [
              OpenStruct.new(name: "Content-Type", value: "text/html; charset=\"UTF-8\""),
              OpenStruct.new(name: "Content-Transfer-Encoding", value: "quoted-printable")
            ],
            mime_type: "text/html",
            part_id: "1"
          )
        ]
      ),
      size_estimate: 10261,
      snippet: "This is a test message with plain text content. Here are some updates: First update item Second update item Third update item",
      thread_id: "198e70ea89d45b7f"
    )

    # Should handle multipart/alternative structure without errors
    assert_nothing_raised do
      Message.cache_from_gmail(topic, gmail_message)
    end
  end
end
