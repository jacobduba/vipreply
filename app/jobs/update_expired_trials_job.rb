class UpdateExpiredTrialsJob < ApplicationJob
  queue_as :default

  def perform
    Account.trialing
      .where("subscription_period_end < ?", Time.current)
      .update_all(billing_status: :trial_expired)
  end
end
