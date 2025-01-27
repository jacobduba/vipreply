# frozen_string_literal: true

class Template < ApplicationRecord
  MIN_TEMPLATE_SIZE = 3
  MAX_TEMPLATE_SIZE = 6000

  belongs_to :inbox
  has_many :topics
  has_many :examples, dependent: :destroy

  validates :output,
    uniqueness: true,
    length: {in: MIN_TEMPLATE_SIZE..MAX_TEMPLATE_SIZE}

  before_save :strip_output, if: :output_changed?

  before_destroy :remove_template_from_topics

  private

  def remove_template_from_topics
    # Don't nullify, we just set the status to template_removed and it's
    # assumed the template is deleted
    topics.update_all(template_status: :template_removed, template_id: nil)
  end

  def strip_output
    self.output = output.strip
  end
end
