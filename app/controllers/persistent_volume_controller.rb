class PersistentVolumeController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include ContainersCommonMixin
  include GenericListMixin

  private

  def display_name
    _("Volumes")
  end

  menu_section :cnt
end
