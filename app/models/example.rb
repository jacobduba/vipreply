class Example < ApplicationRecord
  belongs_to :template
  belongs_to :message
  belongs_to :inbox

  has_neighbors :message_embedding

  validates :message, presence: true

  before_save :generate_message_embedding, if: :message_id_changed?

  def self.find_best_template(message, inbox)
    embedding = message.generate_embedding

    best_example = inbox.examples
      .nearest_neighbors(:message_embedding, embedding, distance: "inner_product")
      .select(:id, :template_id)
      .first

    best_example.template
  end

  private

  def generate_message_embedding
    self.message_embedding = message.generate_embedding
  end
end
