class EmsDatawarehouseController < ApplicationController
  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include EmsCommon
  include Mixins::EmsCommonAngular
  include Mixins::GenericSessionMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::DatawarehouseManager
  end

  def self.table_name
    @table_name ||= "ems_datawarehouse"
  end

  def show_link(ems, options = {})
    ems_datawarehouse_path(ems.id, options)
  end

  def ems_path(*args)
    ems_datawarehouse_path(*args)
  end

  def listicon_image(item, _view)
    item.decorate.try(:listicon_image)
  end

  def new_ems_path
    new_ems_datawarehouse_path
  end

  def restful?
    true
  end

  def ems_datawarehouse_form_fields
    ems_form_fields
  end

  menu_section :dwh
end
