class AddTemplateStatusToTopics < ActiveRecord::Migration[8.0]
  def change
    add_column :topics, :template_status, :integer, default: 0
  end
end
