# frozen_string_literal: true

# OpenAI lets us submit 8191 tokens... if the characters are under 3000
# characters we can't go over 8191 tokens lol
MAX_INPUT_OUTPUT_SIZE = 3000

class Template < ApplicationRecord
  has_neighbors :input_embedding
  validates :input, uniqueness: true, length: {in: 3..MAX_INPUT_OUTPUT_SIZE}
  validates :output, length: {in: 3..MAX_INPUT_OUTPUT_SIZE}
  belongs_to :inbox

  def to_s
    "Template[input: '#{input}', output: '#{output}']"
  end
end
