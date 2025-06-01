# frozen_string_literal: true

class Template < ApplicationRecord
  MIN_TEMPLATE_SIZE = 3
  MAX_TEMPLATE_SIZE = 6000

  belongs_to :account  
  has_and_belongs_to_many :topics
  has_and_belongs_to_many :message_embeddings

  validates :output, length: {in: MIN_TEMPLATE_SIZE..MAX_TEMPLATE_SIZE}

  before_save :strip_output, if: :output_changed?

  private

  def messages
    Message.where(id: message_embeddings.pluck(:message_id))
  end

  def strip_output
    self.output = output.strip
  end
end
