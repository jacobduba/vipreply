class ChangeTemplateAssociationFromInboxToAccount < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing foreign key constraint
    remove_foreign_key :templates, :inboxes
    
    # Remove inbox_id column
    remove_reference :templates, :inbox
    
    # Add account_id column
    add_reference :templates, :account, null: false, foreign_key: true
  end
end