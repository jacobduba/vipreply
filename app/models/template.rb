# frozen_string_literal: true

class Template < ApplicationRecord
  # OpenAI lets us submit 8191 tokens... if the characters are under 3000
  # characters we can't go over 8191 tokens lol
  MAX_INPUT_OUTPUT_SIZE = 3000

  belongs_to :inbox
  has_many :topics

  has_neighbors :input_embedding
  validates :input, uniqueness: true, length: {in: 3..MAX_INPUT_OUTPUT_SIZE}
  validates :output, length: {in: 3..MAX_INPUT_OUTPUT_SIZE}

  before_destroy :mark_topics_template_removed

  def to_s
    "Template[input: '#{input}', output: '#{output}']"
  end

  private

  def mark_topics_template_removed
    # Don't nullify, we just set the status to template_removed and it's assumed the template is deleted
    topics.update_all(template_status: :template_removed, template_id: nil)
  end
end
