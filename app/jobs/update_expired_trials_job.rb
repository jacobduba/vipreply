class UpdateExpiredTrialsJob < ApplicationJob
  queue_as :default

  def perform
    updated_count = Account.trialing
      .where("subscription_period_end < ?", Time.current)
      .update_all(billing_status: :trial_expired)
  end
end
