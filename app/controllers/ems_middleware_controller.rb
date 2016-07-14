class EmsMiddlewareController < ApplicationController
  include EmsCommon
  include ProvidersSettings

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
    @lastaction = "show_list"
    @angular_app_name = 'miq.provider'
  end

  #    _____ ______ _______
  #   / ____|  ____|__   __|
  #  | |  __| |__     | |
  #  | | |_ |  __|    | |
  #  | |__| | |____   | |
  #   \_____|______|  |_|
  def new
    redirect_to :action => :index, :anchor => "new"
  end

  def show_list
    redirect_to :action => :index, :anchor => "show_list/" +
                                              session[:settings][:views][:manageiq_providers_middlewaremanager]
  end

  def list_providers
    render :json => generate_providers
  end

  def types
    form_instances
    render :json => new_provider_views(types_to_hash(@ems_types))
  end

  #   _____   ____   _____ _______
  #  |  __ \ / __ \ / ____|__   __|
  #  | |__) | |  | | (___    | |
  #  |  ___/| |  | |\___ \   | |
  #  | |    | |__| |____) |  | |
  #  |_|     \____/|_____/   |_|
  def new_provider
    result_object = provider_validator
    if result_object[:result]
      store_provider result_object
    end
    render :json => result_object
  end

  def validate_provider
    status = provider_validator
    render :json => status
  end

  def edit_tags
    session[:tag_items] = params[:miq_grid_checks]
    render :json => {'db' => model}
  end

  def delete_provider
    params[:pressed] = "ems_middleware_delete"
    emss = find_checked_items
    process_emss(emss, "destroy") unless emss.empty?
    render :json => {'removedIds' => emss}
  end

  private

  def store_provider(result_object)
    set_record_vars(result_object[:ems_object])
    if valid_record?(result_object[:ems_object]) && result_object[:ems_object].save
      AuditEvent.success(build_created_audit(result_object[:ems_object], @edit))
      session[:edit] = nil
    else
      result_object[:result] = false
      result_object[:validation_errors] = @edit[:errors]
      result_object[:database_errors] = result_object[:ems_object].errors
    end
  end

  def provider_validator
    create_or_edit
    middleware_provider = model.model_from_emstype(@edit[:new][:emstype]).new
    result_object = create_validation_object middleware_provider
    result_object[:ems_object] = middleware_provider
    result_object
  end

  def create_or_edit
    @ems = model.new
    @edit = {}
    @edit[:key] = "ems_edit__#{@ems.id || "new"}"
    @edit[:new] = {}
    @edit[:current] = {}
    get_form_vars
  end

  def listicon_image(item, _view)
    icon = item.decorate.try(:listicon_image)
  end
end
