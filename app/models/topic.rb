class Topic < ApplicationRecord
  belongs_to :inbox
  belongs_to :template, optional: true

  has_many :messages, dependent: :destroy
  has_many :attachments, through: :messages

  enum :template_status, [:no_templates_exist_at_generation, :template_removed, :template_attached]
end
