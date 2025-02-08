class AddLabelsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :labels, :string, array: true, default: []
  end
end
