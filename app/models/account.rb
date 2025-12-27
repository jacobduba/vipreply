# frozen_string_literal: true

class Account < ApplicationRecord
  class NoGmailPermissionsError < StandardError; end

  has_one :inbox, dependent: :destroy

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  encrypts :access_token
  encrypts :refresh_token

  attribute :has_gmail_permissions, :boolean, default: false

  enum :billing_status, {
    setup: 0,           # gmail not connected
    trialing: 1,        # trial active
    active: 2,          # can use everything
    past_due: 3,        # payment issue
    canceled: 4,        # access revoked
    suspended: 5,       # we suspended them
    trial_expired: 6    # trial ended without payment
  }

  def trial_days_remaining
    return 0 unless trialing? && subscription_period_end.present?
    (subscription_period_end.to_date - Date.current).to_i
  end

  # Note on permissions
  # - If account is disconencted we we sign the person out and show error message
  # - If account doesnt have enough scopes we should the kinda oauth screen to prompt to grant permissions

  # Returns Google credentials for Gmail API operations
  # This method should only be called when has_gmail_permissions is true
  # Throws Google::Apis::AuthorizationError if tokens are invalid/revoked
  def google_credentials
    scopes = [ "email", "profile" ]
    if has_gmail_permissions
      scopes += [ "https://www.googleapis.com/auth/gmail.readonly", "https://www.googleapis.com/auth/gmail.send" ]
    end

    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      refresh_token: refresh_token,
      access_token: access_token,
      expires_at: expires_at,
      scope: scopes
    )

    # Refresh 10 seconds before expiration to avoid race conditions
    if expires_at < Time.current + 10.seconds
      credentials.refresh!
      update!(
        access_token: credentials.access_token,
        expires_at: credentials.expires_at
      )
    end

    credentials
  end

  def with_gmail_service
    raise NoGmailPermissionsError, "Account #{email} lacks Gmail permissions" unless has_gmail_permissions

    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = google_credentials

    yield service
  rescue Signet::AuthorizationError => e
    # Raised when refresh token is invalid/revoked (user disconnected app completely)
    Rails.logger.error "Refresh token revoked/invalid for #{email}: #{e.message}"
    update!(has_gmail_permissions: false)
    raise NoGmailPermissionsError, "Account #{email} lost Gmail permissions"
  rescue Google::Apis::AuthorizationError => e
    # Raised for 401 errors - may occur when user disconnects app
    Rails.logger.error "Authorization failed for #{email}: #{e.message}"
    update!(has_gmail_permissions: false)
    raise NoGmailPermissionsError, "Account #{email} lost Gmail permissions"
  end

  def refresh_gmail_watch
    # Documentation for setting this up in Cloud Console
    # https://developers.google.com/gmail/api/guides/push

    return unless provider == "google_oauth2"

    if Rails.env.development?
      Rails.logger.info "[DEV MODE] Would refresh Gmail watch for #{email}"
      return
    end

    Rails.logger.info "Setting up Gmail watch for #{email}"

    unless inbox.present?
      Rails.logger.error "Inbox not found for account #{email}."
      return
    end

    with_gmail_service do |service|
      watch_request = Google::Apis::GmailV1::WatchRequest.new(
        label_ids: [ "INBOX" ],
        topic_name: Rails.application.credentials.gmail_topic_name
      )

      response = service.watch_user("me", watch_request)
      Rails.logger.info "Gmail watch started for #{email}, history_id: #{response.history_id}"
    end

    nil
  end

  def self.refresh_all_gmail_watches
    where(provider: "google_oauth2", has_gmail_permissions: true)
      .find_each do |account|
      # TODO add db attr to account
      # WHY? right now we have the provider: "google_oauth2".
      # cool if we could also do provider: "google_oauth2", subscribed: true
      # Instead of loading all accounts rn
      next unless account.has_access?

      begin
        account.refresh_gmail_watch
      rescue Account::NoGmailPermissionsError
        # when this error is thrown has_gmail_permissions is set to false automatically
        # so just do notthing
      rescue => e
        # swallow the error so app can continue refreshing accounts
        Rails.error.report(e)
      end
    end
  end

  def has_access?
    trialing? || active?
  end

  # Delivery logic is provider-specific, so it lives on Account.
  # When we support multiple inboxes per account, this moves to Inbox.
  def deliver_reply(topic, reply_text)
    case provider
    when "google_oauth2"
      deliver_reply_via_gmail(topic, reply_text)
    when "mock"
      deliver_reply_mock(topic, reply_text)
    else
      raise "Unknown provider: #{provider}"
    end
  end

  def create_demo_data
    return unless inbox.present?

    demo_data = YAML.load_file(Rails.root.join("config/demo_data.yml"))

    templates = create_demo_templates(demo_data["templates"])
    create_demo_topics(demo_data["topics"], templates)
  end

  private

  def deliver_reply_via_gmail(topic, reply_text)
    most_recent_message = topic.messages.order(date: :desc).first
    raw_email_reply = most_recent_message.create_reply(reply_text, self)

    with_gmail_service do |service|
      message_object = Google::Apis::GmailV1::Message.new(
        raw: raw_email_reply,
        thread_id: topic.thread_id
      )
      service.send_user_message("me", message_object)
    end

    FetchGmailThreadJob.perform_now topic.inbox.id, topic.thread_id
  end

  def deliver_reply_mock(topic, reply_text)
    most_recent_message = topic.messages.order(date: :desc).first

    # Create outbound message locally (simulates sent email)
    # TODO? Replace Gmail labels with VIPReply-specific label system it just seems weird
    topic.messages.create!(
      message_id: "#{topic.thread_id}-#{SecureRandom.hex(8)}@mock.vipreply.local",
      subject: "Re: #{topic.subject}",
      from_name: name,
      from_email: email,
      to_name: most_recent_message.from_name,
      to_email: most_recent_message.from_email,
      plaintext: reply_text,
      html: ActionController::Base.helpers.simple_format(reply_text),
      snippet: reply_text.truncate(100),
      date: Time.current,
      internal_date: Time.current,
      labels: [ "SENT" ]
    )

    # FetchGmailThreadJob marks as awaiting customer response, so mock should too
    topic.update!(status: :no_action_required_awaiting_customer)
  end

  def create_demo_templates(template_data)
    template_data.map do |data|
      inbox.templates.create!(output: data["output"], auto_reply: data["auto_reply"])
    end
  end

  def create_demo_topics(topics_data, templates)
    topics_data.each do |topic_data|
      messages_data = topic_data["messages"]
      last_message = messages_data.last

      topic = inbox.topics.create!(
        thread_id: topic_data["thread_id"],
        subject: topic_data["subject"],
        from_name: last_message["from_name"],
        from_email: last_message["from_email"],
        to_name: last_message["to_name"],
        to_email: last_message["to_email"],
        snippet: last_message["plaintext"].truncate(100),
        date: message_time(last_message),
        message_count: messages_data.count,
        status: topic_data["status"],
        generated_reply: topic_data["generated_reply"]
      )

      messages_data.each do |msg_data|
        topic.messages.create!(
          message_id: "#{topic_data["thread_id"]}-#{SecureRandom.hex(8)}@mock.metricsmith.com",
          subject: topic_data["subject"],
          from_name: msg_data["from_name"],
          from_email: msg_data["from_email"],
          to_name: msg_data["to_name"],
          to_email: msg_data["to_email"],
          plaintext: msg_data["plaintext"],
          html: ActionController::Base.helpers.simple_format(msg_data["plaintext"]),
          snippet: msg_data["plaintext"].truncate(100),
          date: message_time(msg_data),
          internal_date: message_time(msg_data),
          labels: [ "INBOX" ]
        )
      end

      selected_templates = topic_data["template_indices"].map { |i| templates[i] }
      topic.templates = selected_templates if selected_templates.any?
    end
  end

  def message_time(msg_data)
    if msg_data["hours_ago"]
      msg_data["hours_ago"].hours.ago
    elsif msg_data["minutes_ago"]
      msg_data["minutes_ago"].minutes.ago
    else
      Time.current
    end
  end
end
