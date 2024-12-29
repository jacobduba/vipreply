class Topic < ApplicationRecord
  belongs_to :inbox
  has_many :messages, dependent: :destroy
end
