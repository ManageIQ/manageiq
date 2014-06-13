class MoveLogCollectionDepotSettingsToFileDepot < ActiveRecord::Migration
  class Authentication < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Configuration < ActiveRecord::Base
    serialize :settings, Hash
    self.inheritance_column = :_type_disabled # disable STI
  end

  class FileDepot < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class MiqServer < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  class Zone < ActiveRecord::Base
    serialize :settings, Hash
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :miq_servers, :log_file_depot_id, :bigint
    add_column :zones,       :log_file_depot_id, :bigint

    say_with_time("Moving log_depot configuration from settings to FileDepots") do
      Zone.all.each do |zone|
        move_log_settings_to_file_depot("Zone", zone.id, zone.settings)
        zone.save
      end

      Configuration.where(:typ => "vmdb").each do |config|
        move_log_settings_to_file_depot("MiqServer", config.miq_server_id, config.settings)
        config.save
      end
    end
  end

  def down
    remove_column :miq_servers, :log_file_depot_id
    remove_column :zones,       :log_file_depot_id

    # TODO: Down Migration?
  end

  private

  def create_authentication(depot, settings)
    Authentication.create!(
      :authtype      => "default",
      :name          => "FileDepot",
      :userid        => settings[:username],
      :password      => MiqPassword.try_encrypt(settings[:password]),
      :resource_id   => depot.id,
      :resource_type => "FileDepot",
      :type          => "AuthUseridPassword"
    )
  end

  def create_depot(resource_type, resource_id, settings)
    depot = FileDepot.create!(
      :resource_type => resource_type,
      :resource_id   => resource_id,
      :uri           => settings[:uri],
    )

    self.class.const_get(resource_type).where(:id => resource_id).update_all(:log_file_depot_id => depot.id)

    depot
  end

  def move_log_settings_to_file_depot(resource_type, resource_id, config)
    settings = config.delete("log_depot") || config.delete(:log_depot)
    return if settings.blank?

    settings.symbolize_keys!
    depot = create_depot(resource_type, resource_id, settings)
    create_authentication(depot, settings)
  end
end
