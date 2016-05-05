class EmsContainerController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud/Container controllers
  include Mixins::EmsCommonAngular
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::ContainerManager
  end

  def self.table_name
    @table_name ||= "ems_container"
  end

  def ems_path(*args)
    ems_container_path(*args)
  end

  def new_ems_path
    new_ems_container_path
  end

  def ems_container_form_fields
    ems_form_fields
  end

  private

  ############################
  # Special EmsCloud link builder for restful routes
  def show_link(ems, options = {})
    ems_path(ems.id, options)
  end

  def restful?
    true
  end
  public :restful?
end
