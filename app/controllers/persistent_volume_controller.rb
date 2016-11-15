class PersistentVolumeController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  private

  def display_name
    _("Volumes")
  end

  menu_section :cnt
end
