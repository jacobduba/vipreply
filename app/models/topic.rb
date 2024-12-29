class Topic < ApplicationRecord
  belongs_to :inbox
  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages
end
