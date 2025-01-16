class CreateInboxes < ActiveRecord::Migration[8.0]
  def change
    create_table :inboxes do |t|
      t.string :access_token
      t.string :refresh_token

      t.timestamps
    end
  end
end
