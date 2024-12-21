# frozen_string_literal: true

class RenameCollectionsToModels < ActiveRecord::Migration[7.1]
  def change
    rename_table :collections, :models
  end
end
