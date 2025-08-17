require "test_helper"

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
end
