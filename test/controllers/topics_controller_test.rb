require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated when accessing a topic" do
    topic = topics(:acc1_topic1)
    get topic_path(topic)
    assert_redirected_to sign_in_path
  end

  test "account can view a topic it owns" do
    login_as_account1

    acc1_topic1 = topics(:acc1_topic1)
    get topic_path(acc1_topic1)

    assert_response 200
  end

  test "prevents accounts from viewing other accounts topics" do
    login_as_account1

    acc2_topic1 = topics(:acc2_topic1)
    get topic_path(acc2_topic1)

    assert_response 404
  end
end
