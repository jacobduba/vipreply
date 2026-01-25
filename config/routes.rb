# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # OAuth
  get "auth/:provider/callback", to: "sessions#google_auth", as: :auth_callback
  get "auth/failure", to: redirect("/")

  # Prevent showing error when you go to another extension like .zip just show a does not exist page
  constraints(format: /html|turbo_stream/) do
    root "inboxes#index"
    get "/", to: "inboxes#index", as: :inbox

    # Session management
    get "sign_in", to: "sessions#sign_in", as: :sign_in
    get "sign_up", to: "sessions#sign_up", as: :sign_up
    delete "logout", to: "sessions#destroy"
    get "upgrade_permissions", to: "sessions#upgrade_permissions", as: :upgrade_permissions
    get "mock", to: "sessions#mock", as: :mock_sign_in if Rails.env.development?

    # Dashboard for Solid Queue
    mount MissionControl::Jobs::Engine, at: "/jobs"

    # Checkout
    get "checkout/plans", to: "checkout#plans"
    post "checkout/subscribe", to: "checkout#subscribe"
    get "checkout/success", to: "checkout#success"
    get "checkout/error", to: "checkout#error"
    get "checkout/cancel", to: "checkout#cancel"

    # Inbox utilities
    get "update", to: "inboxes#update", as: :refresh_inbox

    # Settings
    get "settings", to: "settings#index"
    delete "settings/cancel_subscription", to: "settings#cancel_subscription"
    post "settings/reactivate_subscription", to: "settings#reactivate_subscription"

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

    resources :attachments, only: [ :show ]
  end

  constraints(format: /json/) do
    # Webhooks
    post "/webhooks/gmail", to: "webhooks#gmail"
    post "/webhooks/stripe", to: "webhooks#stripe"
  end
end
