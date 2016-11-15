module OpsHelper::MyServer
  delegate :id, :to => :my_server, :prefix => true

  def my_zone_name
    my_server.my_zone
  end

  def my_server
    @my_server ||= MiqServer.my_server(true)
  end
end
