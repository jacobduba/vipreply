module Providers
  module BaseProvider
    extend ActiveSupport::Concern

    # Common methods that work across providers
    def credentials
      raise NotImplementedError, "#{self.class} must implement credentials"
    end

    def refresh_token!
      raise NotImplementedError, "#{self.class} must implement refresh_token!"
    end

    def watch_for_changes
      raise NotImplementedError, "#{self.class} must implement watch_for_changes"
    end
  end
end
