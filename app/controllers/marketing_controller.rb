# frozen_string_literal: true

class MarketingController < ApplicationController
  REDCARPET = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(with_toc_data: true))
  PRIVACY_HTML = REDCARPET.render(File.read(Rails.root.join("app", "views", "marketing", "privacy.md")))
  TERMS_HTML = REDCARPET.render(File.read(Rails.root.join("app", "views", "marketing", "terms.md")))

  def home
    if session[:account_id]
      redirect_to inbox_path
    end
  end

  def parking
    render :home, locals: {
      hero_pill: "Built for parking lots",
      hero_subtext: "Handle parking lot customer emails with 10x less effort.",
      pathos_1_title: "Stop re-explaining policies",
      pathos_1_desc: "VIPReply remembers your rates, rules, and refund policies.",
      pathos_2_desc: "Generate patient and helpful replies for stressed travelers."
    }
  end

  def privacy
    @html_content = PRIVACY_HTML
    render :markdown_page
  end

  def terms
    @html_content = TERMS_HTML
    render :markdown_page
  end
end
