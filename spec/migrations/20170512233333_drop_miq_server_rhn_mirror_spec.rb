require_migration

describe DropMiqServerRhnMirror do
  let(:server_role_stub)     { migration_stub(:ServerRole) }
  let(:assigned_role_stub)   { migration_stub(:AssignedServerRole) }
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  let(:role_name) { "rhn_mirror" }

  migration_context :up do
    it "removes the server role" do
      role = server_role_stub.create!(:name => role_name)
      assigned_role_stub.create!(:server_role_id => role.id)

      migrate

      expect(server_role_stub.where(:name => role_name)).to be_empty
      expect(assigned_role_stub.where(:server_role_id => role.id)).to be_empty
    end

    it "removes the role from currently configured servers" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/server/role",
        :value         => "database_operations,event,reporting,scheduler,#{role_name}"
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/server/role",
        :value         => "ems_operations,ems_inventory,#{role_name},user_interface"
      )

      migrate

      settings_change_stub.where(:key => "/server/role").each do |change|
        expect(change.value).to_not include(role_name)
      end
    end

    it "cleans up external files on an appliance" do
      expect(Rails.env).to receive(:production?).and_return(true)
      expect(File).to receive(:exist?).with('/var/www/miq/vmdb').and_return(true)

      mock_fstab_lines = ["/dev/sda / xfs defaults 0 0", "/dev/sdb /repo xfs defaults 0 0"]
      expect(File).to receive(:read).with("/etc/fstab").and_return(mock_fstab_lines.join("\n"))
      expect(File).to receive(:write).with("/etc/fstab", "/dev/sda     / xfs defaults        0        0 \n")

      expect(FileUtils).to receive(:rm_f).with("/etc/httpd/conf.d/manageiq-https-mirror.conf")
      expect(FileUtils).to receive(:rm_f).with("/etc/yum.repos.d/manageiq-mirror.repo")
      expect(FileUtils).to receive(:rm_rf).with([])

      migrate
    end
  end
end
