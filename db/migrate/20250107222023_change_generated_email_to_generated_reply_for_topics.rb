class ChangeGeneratedEmailToGeneratedReplyForTopics < ActiveRecord::Migration[8.0]
  def change
    rename_column :topics, :generated_email, :generated_reply
  end
end
