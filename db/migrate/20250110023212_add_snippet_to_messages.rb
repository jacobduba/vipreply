class AddSnippetToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :snippet, :string
  end
end
