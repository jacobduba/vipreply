class AddContentIdToAttachments < ActiveRecord::Migration[8.0]
  def change
    add_column :attachments, :content_id, :string
  end
end
