Rails.application.railties.each do |railtie|
  next unless (railtie.class.name.start_with?("ManageIQ::Providers::") || railtie.try(:vmdb_plugin?))
  Vmdb::Plugins.instance.register_vmdb_plugin(railtie)
end
