module ManageIQ::Providers::Amazon::CloudManager::Vm::Operations::Instance
  def validate_timeline
    {:available => false,
     :message   => _("Timeline is not available for %{model}") % {:model => ui_lookup(:model => self.class.to_s)}}
  end
end
