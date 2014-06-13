class SubclassFileDepotByProtocol < ActiveRecord::Migration
  class FileDepot < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    add_column :file_depots, :type, :string

    say_with_time("Sub-classing all FileDepots") do
      FileDepot.all.each do |fd|
        fd.update_attributes(:type => type_from_uri(fd.uri.to_s))
      end
    end
  end

  def down
    remove_column :file_depots, :type
  end

  private

  PROTOCOL_TRANSLATIONS = Hash.new("FileDepot").merge(
      'ftp' => 'FileDepotFtp',
      'nfs' => 'FileDepotNfs',
      'smb' => 'FileDepotSmb',
    )

  def type_from_uri(uri)
    protocol = URI(uri).scheme

    PROTOCOL_TRANSLATIONS[protocol]
  end
end
