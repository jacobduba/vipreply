class CreateJoinTableTemplatesTopics < ActiveRecord::Migration[8.0]
  def change
    create_join_table :templates, :topics do |t|
      t.index :template_id
      t.index :topic_id
    end
  end
end