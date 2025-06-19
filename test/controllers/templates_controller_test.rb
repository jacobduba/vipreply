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
    patch template_path(acc2_template1), params: {template: {output: "..."}}

    assert_response 404
  end
end
