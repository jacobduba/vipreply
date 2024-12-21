# frozen_string_literal: true

class Model < ApplicationRecord
  has_many :examples, dependent: :destroy
  has_and_belongs_to_many :accounts
  validates :name, length: {in: 3...30}
end
