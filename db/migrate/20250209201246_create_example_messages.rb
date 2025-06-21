class CreateExampleMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :example_messages do |t|
      t.references :inbox, null: false, foreign_key: true
      t.string :subject
      t.text :body
      t.timestamps
    end
  end
end
