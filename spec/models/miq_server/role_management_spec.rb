RSpec.describe "Server Role Management" do
  context "After Setup," do
    before do
      MiqRegion.seed
      ServerRole.seed
      @server_roles = ServerRole.all
      @miq_server   = EvmSpecHelper.local_miq_server
      @miq_server.deactivate_all_roles
    end

    context "#apache_needed?" do
      it "false with neither webservices or user_interface active" do
        allow(@miq_server).to receive_messages(:active_role_names => ["reporting"])
        expect(@miq_server.apache_needed?).to be_falsey
      end

      it "true with only cockpit_ws active" do
        allow(@miq_server).to receive_messages(:active_role_names => ["cockpit_ws"])
        expect(@miq_server.apache_needed?).to be_truthy
      end

      it "true with web_services active" do
        allow(@miq_server).to receive_messages(:active_role_names => ["web_services"])
        expect(@miq_server.apache_needed?).to be_truthy
      end

      it "true with both web_services and user_interface active" do
        allow(@miq_server).to receive_messages(:active_role_names => ["web_services", "user_interface"])
        expect(@miq_server.apache_needed?).to be_truthy
      end

      it "true with all three active" do
        roles = %w("web_services user_interface cockpit_ws")
        allow(@miq_server).to receive_messages(:active_role_names => roles)
        expect(@miq_server.apache_needed?).to be_truthy
      end
    end

    context "role=" do
      it "normal case" do
        @miq_server.assign_role(ServerRole.find_by(:name => 'ems_operations'), 1)
        expect(@miq_server.server_role_names).to eq(%w[ems_operations])

        @miq_server.role = 'event,scheduler,user_interface'
        expect(@miq_server.server_role_names).to eq(%w[event scheduler user_interface])
      end

      it "with a duplicate existing role" do
        @miq_server.assign_role(ServerRole.find_by(:name => 'ems_operations'), 1)
        expect(@miq_server.server_role_names).to eq(%w[ems_operations])

        @miq_server.role = 'ems_operations,ems_operations,scheduler'
        expect(@miq_server.server_role_names).to eq(%w[ems_operations scheduler])
      end

      it "with duplicate new roles" do
        @miq_server.assign_role(ServerRole.find_by(:name => 'event'), 1)
        expect(@miq_server.server_role_names).to eq(%w[event])

        @miq_server.role = 'ems_operations,scheduler,scheduler'
        expect(@miq_server.server_role_names).to eq(%w[ems_operations scheduler])
      end

      it "with an invalid role name" do
        expect { @miq_server.role = 'foo' }.to raise_error(ArgumentError, /not defined/)
      end
    end

    context "server_role_names=" do
      it "normal case" do
        @miq_server.assign_role(ServerRole.find_by(:name => 'ems_operations'), 1)
        expect(@miq_server.server_role_names).to eq(%w[ems_operations])

        @miq_server.server_role_names = %w[event scheduler user_interface]
        expect(@miq_server.server_role_names).to eq(%w[event scheduler user_interface])
      end

      it "with a duplicate existing role" do
        @miq_server.assign_role(ServerRole.find_by(:name => 'ems_operations'), 1)
        expect(@miq_server.server_role_names).to eq(%w[ems_operations])

        @miq_server.server_role_names = %w[ems_operations ems_operations scheduler]
        expect(@miq_server.server_role_names).to eq(%w[ems_operations scheduler])
      end

      it "with duplicate new roles" do
        @miq_server.assign_role(ServerRole.find_by(:name => 'event'), 1)
        expect(@miq_server.server_role_names).to eq(%w[event])

        @miq_server.server_role_names = %w[ems_operations scheduler scheduler]
        expect(@miq_server.server_role_names).to eq(%w[ems_operations scheduler])
      end

      it "with an invalid role name" do
        expect { @miq_server.server_role_names = ['foo'] }.to raise_error(ArgumentError, /not defined/)
      end
    end

    it "should assign role properly when requested" do
      @roles = [['ems_operations', 1], ['event', 2], ['ems_metrics_coordinator', 1], ['scheduler', 1], ['reporting', 1]]
      @roles.each do |role, priority|
        asr = @miq_server.assign_role(ServerRole.find_by(:name => role), priority)
        expect(asr.priority).to eq(priority)
        expect(asr.server_role.name).to eq(role)
      end
    end
  end
end
