require "test_helper"

class MarketingControllerTest < ActionDispatch::IntegrationTest
  test "should get landing" do
    get marketing_landing_url
    assert_response :success
  end

  test "should get privacy" do
    get marketing_privacy_url
    assert_response :success
  end
end
