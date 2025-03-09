# app/models/inbox.rb
class Inbox < ApplicationRecord
  belongs_to :account
  has_many :topics, dependent: :destroy

  validates :provider, presence: true
  validates :history_id, numericality: {only_integer: true, greater_than_or_equal_to: 0}, allow_nil: true

  encrypts :access_token
  encrypts :refresh_token

  # Include the appropriate provider module based on the provider attribute
  def self.included_modules
    super + [provider_module]
  end

  def provider_module
    case provider
    when "google_oauth2"
      Providers::GoogleProvider
    when "microsoft_office365"
      Providers::MicrosoftProvider
    else
      raise "Unknown provider: #{provider}"
    end
  end

  # Re-include the provider module when the record is loaded
  after_find do
    extend(provider_module) if provider.present?
  end

  # For new records, include the provider module when creating
  after_initialize do
    extend(provider_module) if provider.present? && new_record?
  end

  def mail_service
    case provider
    when "google_oauth2"
      gmail_service # From GoogleProvider concern
    when "microsoft_office365"
      graph_client # Access Microsoft Graph API
    else
      raise "Unknown provider: #{provider}"
    end
  end

  def setup
    watch_for_changes
  end
end
