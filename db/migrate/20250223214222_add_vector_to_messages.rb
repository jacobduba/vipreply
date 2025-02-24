class AddVectorToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :vector, :vector, limit: 2048
  end
end
