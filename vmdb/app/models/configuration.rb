class Configuration < ActiveRecord::Base
  belongs_to                :miq_server, :foreign_key => "miq_server_id"
  serialize                 :settings,   Vmdb::ConfigurationEncoder

  def self.create_or_update(miq_server, settings_hash, typ)
    log_header = "MIQ(Configuration.create_or_update)"
    db_record  = miq_server.configurations.find_by_typ(typ)

    if db_record
      if settings_hash == db_record.settings
        $log.info("#{log_header} Skipping update since no settings are changed for server configuration: id: [#{db_record.id}], typ: [#{db_record.typ}], miq_server_id: [#{db_record.miq_server_id}]")
      else
        db_record.update_attributes(:settings => settings_hash)
        $log.info("#{log_header} Updated server configuration: id: [#{db_record.id}], typ: [#{db_record.typ}], miq_server_id: [#{db_record.miq_server_id}]")
      end
    else
      db_record = miq_server.configurations.create(:settings => settings_hash, :typ => typ)
      $log.info("#{log_header} Created server configuration in db: id: [#{db_record.id}], typ: [#{db_record.typ}], miq_server_id: [#{db_record.miq_server_id}]")
    end

    db_record
  end
end
