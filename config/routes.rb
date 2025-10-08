# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # OAuth
  get "auth/:provider/callback", to: "sessions#google_auth", as: :auth_callback
  get "auth/failure", to: redirect("/")

  constraints(format: /html|turbo_stream/) do
    # Marketing
    root "marketing#home"
    get "parking", to: "marketing#parking"
    get "privacy", to: "marketing#privacy"
    get "terms", to: "marketing#terms"

    # Session management
    get "sign_in", to: "sessions#sign_in", as: :sign_in
    get "sign_up", to: "sessions#sign_up", as: :sign_up
    delete "logout", to: "sessions#destroy"
    get "upgrade_permissions", to: "sessions#upgrade_permissions", as: :upgrade_permissions

    # Analytics
    get "analytics", to: "analytics#index"

    # Dashboard for Solid Queue
    mount MissionControl::Jobs::Engine, at: "/jobs"

    # Checkout
    get "checkout/plans", to: "checkout#plans"
    post "checkout/subscribe", to: "checkout#subscribe"
    get "checkout/success", to: "checkout#success"
    get "checkout/error", to: "checkout#error"
    get "checkout/cancel", to: "checkout#cancel"

    # Settings
    get "settings", to: "settings#index"
    delete "settings/cancel_subscription", to: "settings#cancel_subscription"
    post "settings/reactivate_subscription", to: "settings#reactivate_subscription"

    # Inbox
    scope :inbox do
      get "", to: "inboxes#index", as: :inbox
      get "update", to: "inboxes#update"

      resources :templates do
        member do
          patch :enable_auto_reply
          patch :disable_auto_reply
        end
      end

      resources :topics do
        member do
          # TODO: delete
          get "template_selector_dropdown"
          get "new_template_dropdown"
          post "create_template_dropdown"
          # END



          post "generate_reply"
          post "send_email"
          post "move_to_requires_action"
          post "move_to_no_action_required"
          patch "change_templates_regenerate_response"
          post "update_templates_regenerate_reply"
          delete "remove_template/:template_id",
            action: :remove_template,
            as: :remove_template
        end
      end

      # Attachments
      get "attachments/:id", to: "attachments#show", as: :attachment
    end
  end

  constraints(format: /json/) do
    # Webhooks
    post "/webhooks/gmail", to: "webhooks#gmail"
    post "/webhooks/stripe", to: "webhooks#stripe"
  end
end
