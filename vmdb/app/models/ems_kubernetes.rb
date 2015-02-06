class EmsKubernetes < EmsContainer
  has_many :container_nodes,                      :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_groups,                     :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_services,                   :foreign_key => :ems_id, :dependent => :destroy

  def self.ems_type
    @ems_type ||= "kubernetes".freeze
  end

  def self.description
    @description ||= "Kubernetes".freeze
  end

  def self.raw_connect(hostname, port, api_version)
    require 'kubeclient'
    require 'uri'

    uri = URI::HTTP.build(:path => "/api", :port => port.to_i)

    # URI::Generic#hostname= was added in ruby 1.9.3 and will automatically
    # wrap an ipv6 address in []
    uri.hostname = hostname
    Kubeclient::Client.new uri.to_s, api_version
  end

  def connect(_options = {})
    self.class.raw_connect(hostname, port, api_version)
  end
end
