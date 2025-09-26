class RemoveConfidenceScoreFromTemplatesTopics < ActiveRecord::Migration[8.0]
  def change
    remove_column :templates_topics, :confidence_score, :decimal
  end
end
