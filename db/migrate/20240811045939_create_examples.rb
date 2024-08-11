class CreateExamples < ActiveRecord::Migration[7.1]
  def change
    create_table :examples do |t|
      t.text :input
      t.text :output
      t.vector :embedding, limit: 3072

      t.timestamps
    end
  end
end
