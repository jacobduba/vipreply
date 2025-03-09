class UpdateTopicsDateColumnAndAddLastUpdated < ActiveRecord::Migration[8.0]
  def change
    # Rename date column to last_message
    rename_column :topics, :date, :last_message

    # Add last_updated column with default to current timestamp
    add_column :topics, :last_updated, :datetime, default: -> { "CURRENT_TIMESTAMP" }
  end
end
