class DropAccountsInboxes < ActiveRecord::Migration[8.0]
  def change
    drop_table :accounts_inboxes
  end
end
