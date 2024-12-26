# frozen_string_literal: true

class Account < ApplicationRecord
  has_and_belongs_to_many :models
  has_one :inbox
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: {scope: :provider}
  validates :email, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
end
