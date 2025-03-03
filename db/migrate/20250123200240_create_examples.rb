class CreateExamples < ActiveRecord::Migration[8.0]
  def change
    create_table :examples do |t|
      t.references :template, null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.vector :message_plaintext_embedding, limit: 2048

      t.timestamps
    end
  end
end
