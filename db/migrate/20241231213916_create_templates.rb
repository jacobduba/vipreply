class CreateTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :templates do |t|
      t.text :input
      t.text :output
      t.vector :input_embedding, limit: 2048
      t.references :inbox, null: false, foreign_key: true

      t.timestamps
    end
  end
end
