require "test_helper"

class BillingControllerTest < ActionDispatch::IntegrationTest
  test "should get subscribe" do
    get billing_subscribe_url
    assert_response :success
  end

  test "should get success" do
    get billing_success_url
    assert_response :success
  end

  test "should get cancel" do
    get billing_cancel_url
    assert_response :success
  end
end
