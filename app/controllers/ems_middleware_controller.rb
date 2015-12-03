class EmsMiddlewareController < ApplicationController
  include EmsCommon

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::MiddlewareManager
  end

  def self.table_name
    @table_name ||= "ems_middleware"
  end

  def index
    redirect_to :action => 'show_list'
  end
end
