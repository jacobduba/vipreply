class Inbox < ApplicationRecord
  belongs_to :account
  has_many :topics, dependent: :destroy
  has_many :templates, dependent: :destroy
  validates :history_id,
    numericality: {only_integer: true, greater_than_or_equal_to: 0},
    allow_nil: true

  attribute :initial_import_jobs_remaining, default: -1
end
