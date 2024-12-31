class Inbox < ApplicationRecord
  belongs_to :account
  has_many :topics, dependent: :destroy
  has_many :templates, dependent: :destroy
end
