class AddDefaultEmptyStringToTopicsGeneratedReply < ActiveRecord::Migration[8.0]
  def change
    change_column_default :topics, :generated_reply, from: nil, to: ""
  end
end
