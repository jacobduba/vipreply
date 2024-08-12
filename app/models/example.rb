MAX_EMBEDDING_LENGTH = 8191

class Example < ApplicationRecord
  has_neighbors :input_embedding
  validates :input, uniqueness: true, length: { in: 3..MAX_EMBEDDING_LENGTH}
  validates :output, length: { in: 3..MAX_EMBEDDING_LENGTH}
end
