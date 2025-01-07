class Topic < ApplicationRecord
  belongs_to :inbox
  belongs_to :template, optional: true
  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages
end
