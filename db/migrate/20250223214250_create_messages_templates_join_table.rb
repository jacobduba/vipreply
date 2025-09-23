class CreateMessagesTemplatesJoinTable < ActiveRecord::Migration[8.0]
  def change
    create_join_table :messages, :templates do |t|
      t.index [ :message_id, :template_id ], unique: true
      t.index [ :template_id, :message_id ]
      t.timestamps
    end
  end
end
