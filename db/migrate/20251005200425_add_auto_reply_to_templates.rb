class AddAutoReplyToTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :templates, :auto_reply, :boolean, default: false
  end
end
