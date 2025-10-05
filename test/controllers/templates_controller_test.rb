require "test_helper"

class TemplatesControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated when accessing a template" do
    template = templates(:acc1_template1)
    get edit_template_path(template)
    assert_redirected_to root_path
  end

  test "account cannot edit other accounts templates" do
    login_as_account1

    acc2_template1 = templates(:acc2_template1)
    patch template_path(acc2_template1), params: { template: { output: "..." } }

    assert_response 404
  end

  test "enables auto reply with turbo stream response" do
    login_as_account1

    template = templates(:acc1_template1)

    patch enable_auto_reply_template_path(template), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], @response.media_type
    assert template.reload.auto_reply?
  end

  test "disables auto reply with turbo stream response" do
    login_as_account1

    template = templates(:acc1_template1)
    template.update!(auto_reply: true)

    patch disable_auto_reply_template_path(template), as: :turbo_stream

    assert_response :success
    assert_equal Mime[:turbo_stream], @response.media_type
    assert_not template.reload.auto_reply?
  end
end
