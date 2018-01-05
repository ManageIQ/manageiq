require "sinatra/base"

class ManageIQ::Providers::BaseManager::Operations < Sinatra::Application
  include Vmdb::Logging

  post '/api/vm/:ref/start' do
    invoke_raw_method("vm_start")
  end

  private

  def invoke_raw_method(name)
    with_provider_connection do |conn|
      send("raw_#{name}", conn, params[:ref], raw_method_args)
    end
  end

  def raw_method_args
    # TODO: YAML encode the args
    params[:args]
  end

  def connections
    @connections ||= Concurrent::Map.new
  end

  def with_provider_connection
    connect_params = params[:connection]

    connections.compute_if_absent(connection_key(connect_params)) { create_connection_pool(connect_params) }
    connections[connection_key(connect_params)].with { |connection| yield connection }
  end

  def create_connection_pool(connect_params)
    connection_pool_opts = {
      :size    => 1,
      :timeout => 30,
    }

    require "connection_pool"
    ConnectionPool.new(connection_pool_opts) { connect(connect_params) }
  end

  def connect(*_)
    raise NotImplementedError, _("must be implemented in subclass")
  end

  def connection_key(*_)
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
