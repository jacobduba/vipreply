class CreateEmbeddings < ActiveRecord::Migration[8.0]
  def change
    create_table :embeddings do |t|
      t.string :embeddable_type, null: false
      t.bigint :embeddable_id, null: false
      t.vector :vector, limit: 2048
      t.references :inbox, null: false, foreign_key: true
      t.timestamps
    end

    add_index :embeddings, [ :embeddable_type, :embeddable_id ]
  end
end
