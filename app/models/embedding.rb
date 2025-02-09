class Embedding < ApplicationRecord
  has_neighbors :vector, dimensions: 2048

  # This polymorphic association lets the embedding come from either a Message or an ExampleMessage.
  belongs_to :embeddable, polymorphic: true
  belongs_to :inbox

  validates :vector, presence: true
end
