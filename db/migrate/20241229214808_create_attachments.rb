class CreateAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :attachments do |t|
      t.string :attachment_id
      t.references :message, null: false, foreign_key: true
      t.string :filename
      t.string :mime_type

      t.timestamps
    end
  end
end
