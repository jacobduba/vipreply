# frozen_string_literal: true

class Inbox < ApplicationRecord
  belongs_to :account
  has_many :topics, dependent: :destroy
  has_many :templates, dependent: :destroy
  validates :history_id,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 },
    allow_nil: true

  # Returns oldest first
  def get_topics_requires_action
    self.topics
      .not_spam
      .where(status: :requires_action)
      .order(date: :asc)
  end

  # Returns newest first
  def get_topics_no_action_required
    self.topics
      .not_spam
      .where(status: [ :no_action_required_marked_by_user, :no_action_required_marked_by_ai, :no_action_required_awaiting_customer, :no_action_required_is_old_email ])
      .order(date: :desc)
  end
end
