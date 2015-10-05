module ManageIQ::Providers::Vmware::InfraManager::VmOrTemplateShared::RefreshOnScan
  def refresh_on_scan
    refresh_advanced_settings
  end

  def refresh_advanced_settings
    return if ext_management_system.nil?

    extra_config = with_provider_object(&:extraConfig)
    return if extra_config.nil?

    hashes = extra_config.collect do |k, v|
      next if k.blank?
      v = nil if v.blank?
      {
        :name  => k,
        :value => v
      }
    end.compact
    EmsRefresh.save_advanced_settings_inventory(self, hashes)
  end
end
