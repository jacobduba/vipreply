class AddColumnsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :internal_date, :datetime
    add_column :messages, :plaintext, :text
    add_column :messages, :html, :text
    remove_column :messages, :body, :text
    remove_column :topics, :messages, :text
  end
end
