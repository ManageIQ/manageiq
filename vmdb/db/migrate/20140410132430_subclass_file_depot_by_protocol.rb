class SubclassFileDepotByProtocol < ActiveRecord::Migration
  class FileDepot < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :file_depots, :type, :string

    say_with_time("Sub-classing all FileDepots") do
      FileDepot.all.each do |fd|
        new_type = type_from_uri(fd.uri.to_s)
        new_type.blank? ? fd.destroy : fd.update_attributes(:type => new_type)
      end
    end
  end

  def down
    remove_column :file_depots, :type
  end

  private

  PROTOCOL_TRANSLATIONS = {
    'ftp' => 'FileDepotFtp',
    'nfs' => 'FileDepotNfs',
    'smb' => 'FileDepotSmb',
  }

  def type_from_uri(uri)
    protocol = URI(uri).scheme

    PROTOCOL_TRANSLATIONS[protocol]
  end
end
