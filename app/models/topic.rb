class Topic < ApplicationRecord
  belongs_to :inbox
  has_many :message, dependent: :destroy
end
