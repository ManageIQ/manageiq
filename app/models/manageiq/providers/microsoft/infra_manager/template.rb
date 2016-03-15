class ManageIQ::Providers::Microsoft::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this VM'
    }
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end
end
