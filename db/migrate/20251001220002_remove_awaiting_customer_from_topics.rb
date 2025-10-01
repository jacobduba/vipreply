class RemoveAwaitingCustomerFromTopics < ActiveRecord::Migration[8.0]
  def change
    remove_column :topics, :awaiting_customer, :boolean
  end
end
