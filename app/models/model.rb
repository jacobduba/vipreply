class Model < ApplicationRecord
  has_many :examples, dependent: :destroy
  validates :name, length: { in: 3...30 }
end
