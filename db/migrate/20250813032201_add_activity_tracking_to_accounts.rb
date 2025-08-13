class AddActivityTrackingToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :session_count, :integer, default: 1 # at least one session if you made an account
    add_column :accounts, :last_active_at, :datetime, default: -> { "CURRENT_TIMESTAMP" }
  end
end
