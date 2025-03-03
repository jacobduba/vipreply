class IncreaseTokenColumnSizeForInboxes < ActiveRecord::Migration[8.0]
  def change
    # Change from string limited to 1020 chars to text type (so we can handle Google or Microsoft auth)
    change_column :inboxes, :access_token, :text
    change_column :inboxes, :refresh_token, :text
  end
end