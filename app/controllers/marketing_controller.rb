class MarketingController < ApplicationController
  skip_before_action :authorize_account

  REDCARPET = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
  PRIVACY_HTML = REDCARPET.render(File.read(Rails.root.join("app", "views", "marketing", "privacy.md")))
  TERMS_HTML = REDCARPET.render(File.read(Rails.root.join("app", "views", "marketing", "terms.md")))

  def landing
    if session[:account_id]
      redirect_to inbox_path
    end
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
