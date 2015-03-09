class EmsInfraController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud controllers

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def self.model
    @model ||= EmsInfra
  end

  def self.table_name
    @table_name ||= "ems_infra"
  end

  def index
    redirect_to :action => 'show_list'
  end

  private ############################
end
