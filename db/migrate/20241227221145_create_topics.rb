class CreateTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :topics do |t|
      t.string :thread_id
      t.string :snippet
      t.text :messages
      t.datetime :date
      t.string :subject
      t.string :from
      t.string :to

      t.timestamps
    end
  end
end
