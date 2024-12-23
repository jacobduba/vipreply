# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

puts "Seeding data for #{Rails.env} environment..."

if Rails.env.development?
  puts "Creating development-specific data..."
  # Example development data
  Account.find_or_create_by(username: "dev") { |account| account.password = "dev" }
  Model.find_or_create_by(name: "The Flowershop") { |model| model.accounts << Account.find_by(username: "dev") }
end

if Rails.env.test?
  puts "Creating test-specific data..."
end

puts "Seeding complete for #{Rails.env}."
