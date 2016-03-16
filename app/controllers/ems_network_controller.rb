class EmsNetworkController < ApplicationController
  include EmsCommon
  include Mixins::EmsCommonAngular
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::NetworkManager
  end

  def self.table_name
    @table_name ||= "ems_network"
  end

  def ems_path(*args)
    ems_network_path(*args)
  end

  def ems_network_form_fields
    ems_form_fields
  end
end
