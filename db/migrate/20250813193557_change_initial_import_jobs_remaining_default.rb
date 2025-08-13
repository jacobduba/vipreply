class ChangeInitialImportJobsRemainingDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :inboxes, :initial_import_jobs_remaining, from: 0, to: -1
  end
end
