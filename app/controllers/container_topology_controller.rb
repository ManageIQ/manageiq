class ContainerTopologyController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def show
    topology = generate_topology(params[:id])
    @topologyitems = topology[:items].to_json
    @topologyrelations = topology[:relations].to_json
    @topologykinds = topology[:kinds].to_json
  end

  def index
    redirect_to :action => 'show'
  end

  def data
    render :json => {:data => generate_topology(params[:id])}
  end

  private

  def get_session_data
    @layout = "container_topology"
  end

  def set_session_data
    session[:layout] = @layout
  end

  def generate_topology(provider_id)
    ContainerTopologyService.new(provider_id).build_topology
  end
end
