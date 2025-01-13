class RenameDoNotReplyToAllTakenCareOf < ActiveRecord::Migration[8.0]
  def change
    rename_column :topics, :do_not_reply, :all_taken_care_of
  end
end
