require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users to login when accessing a topic" do
    topic = topics(:one_topic_1)
    get topic_path(topic)
    assert_redirected_to root_path
  end

  test "prevents users from viewing other users topics" do
    account2_topic = topics(:two_topic_1)

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "123456789",
      credentials: {
        token: "123456789",
        refresh_token: "123456789",
        expires_at: Time.now + 1.hour,
        expires: true,
        scope: "openid https://www.googleapis.com/auth/userinfo.profile https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/gmail.send https://www.googleapis.com/auth/gmail.readonly"
      },
      email: "account1@example.com",
      first_name: "User",
      last_name: "Example",
      image_url: "https://example.com/image.jpg",
      info: {
        email: "user@example.com",
        name: "User Example"
      }
    )

    get auth_callback_path(provider: "google_oauth2")

    get topic_path(account2_topic)

    assert_response 404
  end
end
