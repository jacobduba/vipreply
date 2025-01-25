class AddInboxToExamples < ActiveRecord::Migration[8.0]
  def change
    add_reference :examples, :inbox, null: false, foreign_key: true
  end
end
