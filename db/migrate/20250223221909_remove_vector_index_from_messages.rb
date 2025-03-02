class RemoveVectorIndexFromMessages < ActiveRecord::Migration[8.0]
  def change
    remove_index :messages, :vector, if_exists: true
  end
end
