class TopologyController < ApplicationController
  # subclasses need to provide:
  #
  # @layout = 'xxx_topology';
  # @service_class = XxxTopologyService;

  class << self
    attr_reader :layout
    attr_reader :service_class
  end

  private

  def get_session_data
    @layout = self.class.layout
  end

  def generate_topology(provider_id)
    self.class.service_class.new(provider_id).build_topology
  end
end
