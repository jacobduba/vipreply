class AddAttachmentsToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :attachments, :text
  end
end
