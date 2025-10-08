require "test_helper"

class AttachmentsControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated when accessing a attachmen" do
    attachment = attachments(:acc2_message1_attachment)
    get attachment_path(attachment)
    assert_redirected_to sign_in_path
  end

  test "account cannot edit other accounts attachments" do
    login_as_account1

    attachment = attachments(:acc2_message1_attachment)
    get attachment_path(attachment)

    assert_response 404
  end
end
