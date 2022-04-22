module PhysicalServer::Operations::Lifecycle
  def decommission_server
    change_state(:decommission_server)
  end

  def recommission_server
    change_state(:recommission_server)
  end
end
