class RemoveAttachmentsFromMessages < ActiveRecord::Migration[8.0]
  def change
    remove_column :messages, :attachments, :text
  end
end
