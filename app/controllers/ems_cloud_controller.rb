class EmsCloudController < ApplicationController
  include Mixins::GenericShowMixin
  include EmsCommon        # common methods for EmsInfra/Cloud controllers
  include Mixins::EmsCommonAngular
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::CloudManager
  end

  def self.table_name
    @table_name ||= "ems_cloud"
  end

  def ems_path(*args)
    ems_cloud_path(*args)
  end

  def new_ems_path
    new_ems_cloud_path
  end

  def ems_cloud_form_fields
    ems_form_fields
  end

  # Special EmsCloud link builder for restful routes
  def show_link(ems, options = {})
    ems_path(ems.id, options)
  end

  def restful?
    true
  end
  public :restful?

  menu_section :clo
end
