class FlavorController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include Mixins::GenericButtonMixin

  def self.display_methods
    %w(instances)
  end

  private

  def get_session_data
    @title      = _("Flavor")
    @layout     = "flavor"
    @lastaction = session[:flavor_lastaction]
    @display    = session[:flavor_display]
    @filters    = session[:flavor_filters]
    @catinfo    = session[:flavor_catinfo]
  end

  def set_session_data
    session[:flavor_lastaction] = @lastaction
    session[:flavor_display]    = @display unless @display.nil?
    session[:flavor_filters]    = @filters
    session[:flavor_catinfo]    = @catinfo
  end

  menu_section :clo
end
