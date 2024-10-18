class Account < ApplicationRecord
  has_secure_password
  has_and_belongs_to_many :models
  validates :name, presence: true, uniqueness: true
end
