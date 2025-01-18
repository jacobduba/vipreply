class SyncTopicStatusesWithAllTakenCareOf < ActiveRecord::Migration[8.0]
  def up
    Topic.where(all_taken_care_of: true).update_all(status: Topic.statuses[:has_reply])
  end
end
