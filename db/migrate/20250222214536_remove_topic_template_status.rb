class RemoveTopicTemplateStatus < ActiveRecord::Migration[8.0]
  def change
    remove_column :topics, :template_status
  end
end
