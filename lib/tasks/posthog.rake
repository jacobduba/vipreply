# frozen_string_literal: true

namespace :posthog do
  desc "Backfill all accounts to PostHog"
  task backfill: :environment do
    Account.where.not(provider: "mock").find_each do |account|
      account.identify_in_posthog
      puts "Identified #{account.email}"
    end
  end
end
