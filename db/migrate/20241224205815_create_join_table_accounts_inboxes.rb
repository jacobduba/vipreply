class CreateJoinTableAccountsInboxes < ActiveRecord::Migration[8.0]
  def change
    create_join_table :accounts, :inboxes do |t|
      # t.index [:account_id, :inbox_id]
      # t.index [:inbox_id, :account_id]
    end
  end
end
