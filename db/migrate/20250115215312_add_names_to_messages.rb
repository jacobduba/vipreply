class AddNamesToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :from_name, :string
    add_column :messages, :to_name, :string
    rename_column :messages, :from, :from_email
    rename_column :messages, :to, :to_email
  end
end
