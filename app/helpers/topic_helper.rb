module TopicHelper
  def display_sender(topic, current_user_email)
    (topic.from_email == current_user_email) ? "Me → #{topic.to}" : topic.from
  end
end
