class AddAuthToModels < ActiveRecord::Migration[7.1]
  def change
    add_column :models, :username, :string, default: 'demo'
    add_column :models, :password, :string, default: 'emails'
  end
end
