class AddContentDispositionToAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :attachments, :content_disposition, :integer, null: false, default: 0
  end
end
