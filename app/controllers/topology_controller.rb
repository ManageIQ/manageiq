class TopologyController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  # subclasses need to provide:
  #
  # @layout = 'xxx_topology';
  # @service_class = XxxTopologyService;
  #
  # Layout has to match the route to the controller and in turn the controller
  # name as it is used in the #show action.

  class << self
    attr_reader :layout
    attr_reader :service_class
  end

  def show
    # When navigated here without id, it means this is a general view for all providers (not for a specific provider)
    # all previous navigation should not be displayed in breadcrumbs as the user could arrive from
    # any other page in the application.
    @breadcrumbs.clear if params[:id].nil?
    drop_breadcrumb(:name => _('Topology'), :url => "/#{self.class.layout}/show/#{params[:id]}")
    @lastaction = 'show'
    @display = @showtype = 'topology'
  end

  def index
    redirect_to :action => 'show'
  end

  def data
    render :json => {:data => generate_topology(params[:id])}
  end

  private

  def set_session_data
    session[:layout] = self.class.layout
  end

  def get_session_data
    @layout = self.class.layout
  end

  def generate_topology(provider_id)
    self.class.service_class.new(provider_id).build_topology
  end
end
