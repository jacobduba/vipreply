# frozen_string_literal: true

MAX_EMBEDDING_LENGTH = 8191

class Example < ApplicationRecord
  has_neighbors :input_embedding
  validates :input, uniqueness: true, length: {in: 3..MAX_EMBEDDING_LENGTH}
  validates :output, length: {in: 3..MAX_EMBEDDING_LENGTH}
  belongs_to :model

  def to_s
    "Example[input: '#{input}', output: '#{output}']"
  end
end
