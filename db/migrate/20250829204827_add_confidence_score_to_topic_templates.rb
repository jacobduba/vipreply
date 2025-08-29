class AddConfidenceScoreToTopicTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :templates_topics, :confidence_score, :decimal, precision: 5, scale: 4
  end
end
