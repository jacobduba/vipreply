class AddInitialImportJobsRemainingToInboxes < ActiveRecord::Migration[8.0]
  def change
    add_column :inboxes, :initial_import_jobs_remaining, :integer, default: 0
  end
end
