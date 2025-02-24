# frozen_string_literal: true

class Template < ApplicationRecord
  MIN_TEMPLATE_SIZE = 3
  MAX_TEMPLATE_SIZE = 6000

  belongs_to :inbox
  has_and_belongs_to_many :topics
  has_and_belongs_to_many :messages

  validates :output,
    uniqueness: true,
    length: {in: MIN_TEMPLATE_SIZE..MAX_TEMPLATE_SIZE}

  before_save :strip_output, if: :output_changed?
  before_destroy :remove_template_from_topics

  private

  def remove_template_from_topics
    topics.each do |topic|
      topic.templates.delete(self)
      topic.update(template_status: :template_removed) if topic.templates.empty?
    end
  end

  def strip_output
    self.output = output.strip
  end
end
