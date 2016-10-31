class EmsMiddlewareController < ApplicationController
  include EmsCommon
  include Mixins::EmsCommonAngular

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

  def show_link(ems, options = {})
    ems_middleware_path(ems.id, options)
  end

  def ems_path(*args)
    ems_middleware_path(*args)
  end

  def new_ems_path
    new_ems_middleware_path
  end

  def listicon_image(item, _view)
    icon = item.decorate.try(:listicon_image)
  end

  def restful?
    true
  end

  def ems_middleware_form_fields
    ems_form_fields
  end

  public :restful?

  menu_section :mdl
end
