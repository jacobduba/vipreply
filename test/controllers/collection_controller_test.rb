require "test_helper"

class CollectionControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get collection_index_url
    assert_response :success
  end

  test "should get show" do
    get collection_show_url
    assert_response :success
  end

  test "should get new" do
    get collection_new_url
    assert_response :success
  end
end
