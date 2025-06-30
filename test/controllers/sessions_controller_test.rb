require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "login redirects to upgrade permissions without gmail scopes" do
    login_as_account1(include_gmail_scopes: false)

    follow_redirect!

    assert_equal "/upgrade_permissions", path
    assert_response :success
  end
end
