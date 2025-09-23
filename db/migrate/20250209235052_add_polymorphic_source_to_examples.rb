class AddPolymorphicSourceToExamples < ActiveRecord::Migration[8.0]
  def change
    add_column :examples, :source_id, :integer
    add_column :examples, :source_type, :string

    # Add an index for better query performance
    add_index :examples, [ :source_type, :source_id ]
  end
end
