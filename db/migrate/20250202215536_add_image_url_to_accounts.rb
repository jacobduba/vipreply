class AddImageUrlToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :image_url, :string
  end
end
