class Inbox < ApplicationRecord
  belongs_to :account
  has_many :topics, dependent: :destroy
end
