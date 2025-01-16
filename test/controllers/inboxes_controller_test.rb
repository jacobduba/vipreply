require "test_helper"

class InboxesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get inboxes_index_url
    assert_response :success
  end

  test "should get show" do
    get inboxes_show_url
    assert_response :success
  end
end
