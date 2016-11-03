# used to serve static angular templates from under app/views/static/

class StaticController < ActionController::Base
  # Added to satisfy Brakeman, https://github.com/presidentbeef/brakeman/pull/953
  protect_from_forgery :with => :exception

  # hide_action is gone in Rails, but high_voltage is still using it.
  # https://github.com/thoughtbot/high_voltage/pull/214
  def self.hide_action(*)
  end

  include HighVoltage::StaticPage
end
