module Mixins
  module GenericFormMixin
    def cancel_action(message)
      session[:edit] = nil
      add_flash(message, :warning)
      javascript_redirect previous_breadcrumb_url
    end
  end
end
