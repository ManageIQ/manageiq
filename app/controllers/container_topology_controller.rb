class ContainerTopologyController < ApplicationController
  include TopologyMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  private

  def get_session_data
    @layout = "container_topology"
  end

  def generate_topology(provider_id)
    ContainerTopologyService.new(provider_id).build_topology
  end
end
