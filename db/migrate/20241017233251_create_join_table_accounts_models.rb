class CreateJoinTableAccountsModels < ActiveRecord::Migration[7.1]
  def change
    create_join_table :accounts, :models
  end
end
