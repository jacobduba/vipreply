require "test_helper"

class ResponderControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get responder_index_url
    assert_response :success
  end
end
