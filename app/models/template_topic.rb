# frozen_string_literal: true

class TemplateTopic < ApplicationRecord
  self.table_name = "templates_topics"
  self.primary_key = [ :template_id, :topic_id ]

  belongs_to :template
  belongs_to :topic
end
