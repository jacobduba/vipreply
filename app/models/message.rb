class Message < ApplicationRecord
  belongs_to :topic
  has_many :attachments, dependent: :destroy
end
