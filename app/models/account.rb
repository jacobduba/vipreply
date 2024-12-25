# frozen_string_literal: true

class Account < ApplicationRecord
  has_secure_password
  has_and_belongs_to_many :models
  has_one :inbox
  validates :username, presence: true, uniqueness: true
end
