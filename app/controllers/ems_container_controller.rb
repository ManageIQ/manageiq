class EmsContainerController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud/Container controllers

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

  def index
    redirect_to :action => 'show_list'
  end

  def deployment
    redirect_to :action => 'new', :controller => :openshift_deployment
  end
end
