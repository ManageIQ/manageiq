RSpec.describe "Server Monitor" do
  context "After Setup," do
    before do
      MiqRegion.seed
      ServerRole.seed

      # Do this manually, to avoid caching at the class level
      allow(ServerRole).to receive(:database_owner).and_return(ServerRole.find_by(:name => 'database_owner'))

      @server_roles = ServerRole.all
    end

    it "should respond properly to UI helper methods" do
      @server_roles.each do |server_role|
        expect(server_role.unlimited?).to be_truthy        if server_role.max_concurrent == 0
        expect(server_role.master_supported?).to be_truthy if server_role.max_concurrent == 1
        expect(ServerRole.to_role(server_role)).to eq(server_role)
        expect(ServerRole.to_role(server_role.name)).to eq(server_role)
      end
    end

    context "with 1 Server" do
      before do
        @miq_server = EvmSpecHelper.local_miq_server
        @miq_server.monitor_servers

        @miq_server.deactivate_all_roles
        @miq_server.role = 'event, ems_operations, scheduler, reporting'
      end

      it "should have no roles active after start" do
        expect(@miq_server.server_roles.length).to eq(4)
        expect(@miq_server.inactive_roles.length).to eq(4)
        expect(@miq_server.active_roles.length).to eq(0)
      end

      it "should activate unlimited zone role via activate_in_zone method" do
        rolename = "ems_operations"
        @miq_server.assigned_server_roles.each do |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_zone
        end
        @miq_server.reload
        expect(@miq_server.inactive_roles.length).to eq(3)
        expect(@miq_server.active_role_names.length).to eq(1)
        expect(@miq_server.active_role_names.include?(rolename)).to be_truthy
        expect(@miq_server.inactive_role_names.include?(rolename)).not_to be_truthy
      end

      it "should activate limited zone role via activate_in_zone method" do
        rolename = "event"
        @miq_server.assigned_server_roles.each do |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_zone
        end
        @miq_server.reload
        expect(@miq_server.inactive_roles.length).to eq(3)
        expect(@miq_server.active_role_names.length).to eq(1)
        expect(@miq_server.active_role_names.include?(rolename)).to be_truthy
        expect(@miq_server.inactive_role_names.include?(rolename)).not_to be_truthy
      end

      it "should activate unlimited region role via activate_in_region method" do
        rolename = "reporting"
        @miq_server.assigned_server_roles.each do |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_region
        end
        @miq_server.reload
        expect(@miq_server.inactive_roles.length).to eq(3)
        expect(@miq_server.active_role_names.length).to eq(1)
        expect(@miq_server.active_role_names.include?(rolename)).to be_truthy
        expect(@miq_server.inactive_role_names.include?(rolename)).not_to be_truthy
      end

      it "should activate limited region role via activate_in_region method" do
        rolename = "scheduler"
        @miq_server.assigned_server_roles.each do |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_region
        end
        @miq_server.reload
        expect(@miq_server.inactive_roles.length).to eq(3)
        expect(@miq_server.active_role_names.length).to eq(1)
        expect(@miq_server.active_role_names.include?(rolename)).to be_truthy
        expect(@miq_server.inactive_role_names.include?(rolename)).not_to be_truthy
      end

      context "after initial monitor_servers" do
        before do
          @miq_server.monitor_server_roles
        end

        it "should have all roles active after monitor_servers" do
          expect(@miq_server.active_role_names.length).to eq(4)
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
        end

        it "should deactivate unlimited role via deactivate_in_zone method" do
          rolename = "ems_operations"
          @miq_server.assigned_server_roles.each do |asr|
            next unless asr.server_role.name == rolename
            asr.deactivate_in_zone
          end
          @miq_server.reload
          expect(@miq_server.inactive_roles.length).to eq(1)
          expect(@miq_server.active_role_names.length).to eq(3)
          expect(@miq_server.active_role_names.include?(rolename)).not_to be_truthy
          expect(@miq_server.inactive_role_names.include?(rolename)).to be_truthy
        end

        it "should deactivate limited role via deactivate_in_zone method" do
          rolename = "event"
          @miq_server.assigned_server_roles.each do |asr|
            next unless asr.server_role.name == rolename
            asr.deactivate_in_zone
          end
          @miq_server.reload
          expect(@miq_server.inactive_roles.length).to eq(1)
          expect(@miq_server.active_role_names.length).to eq(3)
          expect(@miq_server.active_role_names.include?(rolename)).not_to be_truthy
          expect(@miq_server.inactive_role_names.include?(rolename)).to be_truthy
        end

        it "should activate newly assigned unlimited zone role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, smartstate'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(5)
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server.active_role_names.include?("smartstate")).to be_truthy
        end

        it "should activate newly assigned limited zone role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, ems_inventory'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(5)
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server.active_role_names.include?("ems_inventory")).to be_truthy
        end

        it "should activate newly assigned unlimited region role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, database_operations'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(5)
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server.active_role_names.include?("database_operations")).to be_truthy
        end

        it "should activate newly assigned limited region role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, notifier'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(5)
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server.active_role_names.include?("notifier")).to be_truthy
        end

        it "should deactivate removed unlimited zone role" do
          @miq_server.role = 'event, scheduler, reporting'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(3)
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
        end

        it "should deactivate removed limited zone role" do
          @miq_server.role = 'ems_operations, scheduler, reporting'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(3)
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
        end

        it "should deactivate removed unlimited region role" do
          @miq_server.role = 'event, ems_operations, scheduler'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(3)
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("scheduler")).to be_truthy
        end

        it "should deactivate removed limited region role" do
          @miq_server.role = 'event, ems_operations, reporting'
          @miq_server.monitor_server_roles
          expect(@miq_server.active_role_names.length).to eq(3)
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
          expect(@miq_server.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server.active_role_names.include?("reporting")).to be_truthy
        end
      end
    end

    context "with 2 Servers in 2 Zones where I am the Master" do
      before do
        @miq_server1 = EvmSpecHelper.local_miq_server(:is_master => true)
        @miq_server1.deactivate_all_roles
        @miq_server1.role = 'event, ems_operations, scheduler, reporting'

        @miq_server2 = FactoryBot.create(:miq_server, :zone => @miq_server1.zone)
        @miq_server2.deactivate_all_roles
        @miq_server2.role = 'event, ems_operations, scheduler, reporting'
      end

      it "should have no roles active after start" do
        expect(@miq_server1.server_roles.length).to eq(4)
        expect(@miq_server1.inactive_roles.length).to eq(4)
        expect(@miq_server1.active_roles.length).to eq(0)

        expect(@miq_server2.server_roles.length).to eq(4)
        expect(@miq_server2.inactive_roles.length).to eq(4)
        expect(@miq_server2.active_roles.length).to eq(0)
      end

      it "should activate unlimited role via activate_in_zone method" do
        rolename = "ems_operations"
        [@miq_server1, @miq_server2].each do |svr|
          svr.assigned_server_roles.each do |asr|
            next unless asr.server_role.name == rolename
            asr.activate_in_zone
          end
        end
        @miq_server1.reload
        @miq_server2.reload
        expect(@miq_server1.inactive_roles.length).to eq(3)
        expect(@miq_server1.active_role_names.length).to eq(1)
        expect(@miq_server1.active_role_names.include?(rolename)).to be_truthy

        expect(@miq_server2.inactive_roles.length).to eq(3)
        expect(@miq_server2.active_role_names.length).to eq(1)
        expect(@miq_server2.active_role_names.include?(rolename)).to be_truthy
      end

      context "after monitor_servers" do
        before do
          @miq_server1.monitor_server_roles
          @miq_server2.reload
        end

        it "should have all roles active after sync between them" do
          expect(@miq_server1.active_role_names.include?("ems_operations") && @miq_server2.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.active_role_names.include?("event") ^ @miq_server2.active_role_names.include?("event")).to be_truthy
          expect(@miq_server1.active_role_names.include?("reporting") && @miq_server2.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server1.active_role_names.include?("scheduler") ^ @miq_server2.active_role_names.include?("scheduler")).to be_truthy
        end
      end

      context "with Non-Master having the active roles" do
        before do
          @miq_server2.activate_roles("event")
          @miq_server1.monitor_server_roles
        end

        it "should have all roles on the desired servers" do
          expect(@miq_server1.active_role_names.include?("ems_operations") && @miq_server2.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.inactive_role_names.include?("event") && @miq_server2.active_role_names.include?("event")).to be_truthy
        end

        context "where Non-Master shuts down cleanly" do
          before do
            @miq_server2.deactivate_all_roles
            @miq_server2.stopped_on = Time.now.utc
            @miq_server2.status = "stopped"
            @miq_server2.is_master = false
            @miq_server2.save!

            @miq_server1.monitor_servers
            @miq_server1.monitor_server_roles
            @miq_server2.reload
          end

          it "should migrate roles to Master" do
            expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server1.active_role_names.include?("event")).to be_truthy
            expect(@miq_server2.active_role_names).to be_empty
          end
        end

        context "where Non-Master is not responding" do
          before do
            @miq_server1.monitor_servers
            Timecop.travel 5.minutes do
              @miq_server1.monitor_servers
            end
          end

          it "should mark server as not responding" do
            expect(@miq_server2.reload.status).to eq("not responding")
          end

          it "should migrate roles to Master" do
            @miq_server1.monitor_server_roles
            @miq_server2.reload

            expect(@miq_server2.server_roles.length).to eq(4)
            expect(@miq_server2.inactive_roles.length).to eq(4)
            expect(@miq_server2.active_roles.length).to eq(0)

            expect(@miq_server1.server_roles.length).to eq(4)
            expect(@miq_server1.inactive_roles.length).to eq(0)
            expect(@miq_server1.active_roles.length).to eq(4)

            expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server1.active_role_names.include?("event")).to be_truthy
            expect(@miq_server1.active_role_names.include?("reporting")).to be_truthy
            expect(@miq_server1.active_role_names.include?("scheduler")).to be_truthy
          end
        end
      end
    end

    context "with 2 Servers where I am the non-Master" do
      before do
        @miq_server1 = EvmSpecHelper.local_miq_server
        @miq_server1.deactivate_all_roles
        @miq_server1.role = 'event, ems_operations, scheduler, reporting'
        @roles1 = [['ems_operations', 1], ['event', 2], ['scheduler', 2], ['reporting', 1]]
        @roles1.each { |role, priority| @miq_server1.assign_role(role, priority) }
        @miq_server1.activate_roles("ems_operations", 'reporting')

        @miq_server2 = FactoryBot.create(:miq_server, :is_master => true, :zone => @miq_server1.zone)
        @miq_server2.deactivate_all_roles
        @miq_server2.role = 'event, ems_operations, scheduler, reporting'
        @roles2 = [['ems_operations', 1], ['event', 1], ['scheduler', 1], ['reporting', 1]]
        @roles2.each { |role, priority| @miq_server2.assign_role(role, priority) }
        @miq_server2.activate_roles("event", "ems_operations", 'scheduler', 'reporting')

        @miq_server1.monitor_servers
      end

      it "should have all roles active after sync between them" do
        expect(@miq_server1.active_role_names.include?("ems_operations") && @miq_server2.active_role_names.include?("ems_operations")).to be_truthy
        expect(@miq_server1.active_role_names.include?("event") ^ @miq_server2.active_role_names.include?("event")).to be_truthy
        expect(@miq_server1.active_role_names.include?("reporting") && @miq_server2.active_role_names.include?("reporting")).to be_truthy
        expect(@miq_server1.active_role_names.include?("scheduler") ^ @miq_server2.active_role_names.include?("scheduler")).to be_truthy
      end

      context "where Master shuts down cleanly" do
        before do
          @miq_server2.deactivate_all_roles
          @miq_server2.stopped_on = Time.now.utc
          @miq_server2.status = "stopped"
          @miq_server2.is_master = false
          @miq_server2.save!
          @miq_server1.monitor_servers
        end

        it "should takeover as Master" do
          expect(@miq_server1.is_master?).to be_truthy
          @miq_server2.reload
          expect(@miq_server2.is_master?).not_to be_truthy
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.active_role_names.include?("event")).to be_truthy
          expect(@miq_server1.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server1.active_role_names.include?("scheduler")).to be_truthy
          @miq_server2.reload
          expect(@miq_server2.active_role_names).to be_empty
        end
      end

      context "where Master is not responding" do
        before do
          Timecop.travel 5.minutes
          @miq_server1.monitor_servers
        end

        after do
          Timecop.return
        end

        it "should takeover as Master" do
          expect(@miq_server1.is_master?).to be_truthy
          @miq_server2.reload
          expect(@miq_server2.is_master?).not_to be_truthy
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload

          expect(@miq_server2.status).to eq("not responding")
          expect(@miq_server2.server_roles.length).to eq(4)
          expect(@miq_server2.inactive_roles.length).to eq(4)
          expect(@miq_server2.active_roles.length).to eq(0)

          expect(@miq_server1.inactive_roles.length).to eq(0)
          expect(@miq_server1.active_roles.length).to eq(4)
          expect(@miq_server1.active_role_names.include?("database_owner")).to be_falsey

          expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.active_role_names.include?("event")).to be_truthy
          expect(@miq_server1.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server1.active_role_names.include?("scheduler")).to be_truthy
        end
      end
    end

    context "with 3 Servers where I am the Master" do
      before do
        @miq_server1 = EvmSpecHelper.local_miq_server(:is_master => true, :name => "Miq1")
        @miq_server1.deactivate_all_roles
        @roles1 = [['ems_operations', 2], ['event', 2], ['ems_inventory', 3], ['ems_metrics_coordinator', 2],]
        @roles1.each { |role, priority| @miq_server1.assign_role(role, priority) }

        @miq_server2 = FactoryBot.create(:miq_server, :zone => @miq_server1.zone, :name => "Miq2")
        @miq_server2.deactivate_all_roles
        @roles2 = [['ems_operations', 1], ['event', 1], ['ems_metrics_coordinator', 3], ['ems_inventory', 2],]
        @roles2.each { |role, priority| @miq_server2.assign_role(role, priority) }

        @miq_server3 = FactoryBot.create(:miq_server, :zone => @miq_server1.zone, :name => "Miq3")
        @miq_server3.deactivate_all_roles
        @roles3 = [['ems_operations', 2], ['event', 3], ['ems_inventory', 1], ['ems_metrics_coordinator', 1]]
        @roles3.each { |role, priority| @miq_server3.assign_role(role, priority) }

        @miq_server1.monitor_servers
        @miq_server1.monitor_server_roles if @miq_server1.is_master?
        @miq_server2.reload
        @miq_server3.reload
      end

      it "should support multiple failover transitions from stopped master" do
        # server1 is first to start, becomes master
        @miq_server1.monitor_servers

        # Initialize the bookkeeping around current and last master
        @miq_server2.monitor_servers
        @miq_server3.monitor_servers

        # server1 is master
        expect(@miq_server1.reload.is_master).to be_truthy
        expect(@miq_server2.reload.is_master).to be_falsey
        expect(@miq_server3.reload.is_master).to be_falsey

        # server 1 shuts down
        @miq_server1.update(:status => "stopped")

        # server 3 becomes master, server 2 hasn't monitored servers yet
        @miq_server3.monitor_servers
        expect(@miq_server1.reload.is_master).to be_falsey
        expect(@miq_server2.reload.is_master).to be_falsey
        expect(@miq_server3.reload.is_master).to be_truthy

        # server 3 shuts down
        @miq_server3.update(:status => "stopped")

        # server 2 finally gets to monitor_servers, takes over
        @miq_server2.monitor_servers
        expect(@miq_server1.reload.is_master).to be_falsey
        expect(@miq_server2.reload.is_master).to be_truthy
        expect(@miq_server3.reload.is_master).to be_falsey
      end

      it "should failover from stopped master on startup" do
        # server 1 is first to start, becomes master
        @miq_server1.monitor_servers

        # server 1 shuts down
        @miq_server1.update(:status => "stopped")

        # server 3 boots and hasn't run monitor_servers yet
        expect(@miq_server1.reload.is_master).to be_truthy
        expect(@miq_server3.reload.is_master).to be_falsey

        # server 3 runs monitor_servers and becomes master
        @miq_server3.monitor_servers
        expect(@miq_server1.reload.is_master).to be_falsey
        expect(@miq_server3.reload.is_master).to be_truthy
      end

      it "should have all roles active after sync between them" do
        expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
        expect(@miq_server2.active_role_names.include?("ems_operations")).to be_truthy
        expect(@miq_server3.active_role_names.include?("ems_operations")).to be_truthy

        expect(@miq_server1.active_role_names.include?("event")).not_to be_truthy
        expect(@miq_server2.active_role_names.include?("event")).to be_truthy
        expect(@miq_server3.active_role_names.include?("event")).not_to be_truthy

        expect(@miq_server1.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
        expect(@miq_server2.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
        expect(@miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy

        expect(@miq_server1.active_role_names.include?("ems_inventory")).not_to be_truthy
        expect(@miq_server2.active_role_names.include?("ems_inventory")).not_to be_truthy
        expect(@miq_server3.active_role_names.include?("ems_inventory")).to be_truthy
      end

      it "should respond to helper methods for UI" do
        expect(@miq_server1.is_master_for_role?("ems_operations")).not_to be_truthy
        expect(@miq_server2.is_master_for_role?("ems_operations")).to be_truthy
        expect(@miq_server3.is_master_for_role?("ems_operations")).not_to be_truthy

        expect(@miq_server1.is_master_for_role?("event")).not_to be_truthy
        expect(@miq_server2.is_master_for_role?("event")).to be_truthy
        expect(@miq_server3.is_master_for_role?("event")).not_to be_truthy

        expect(@miq_server1.is_master_for_role?("ems_inventory")).not_to be_truthy
        expect(@miq_server2.is_master_for_role?("ems_inventory")).not_to be_truthy
        expect(@miq_server3.is_master_for_role?("ems_inventory")).to be_truthy

        expect(@miq_server1.is_master_for_role?("ems_metrics_coordinator")).not_to be_truthy
        expect(@miq_server2.is_master_for_role?("ems_metrics_coordinator")).not_to be_truthy
        expect(@miq_server3.is_master_for_role?("ems_metrics_coordinator")).to be_truthy
      end

      context "when Server3 is stopped" do
        before do
          @miq_server3.deactivate_all_roles
          @miq_server3.stopped_on = Time.now.utc
          @miq_server3.status = "stopped"
          @miq_server3.is_master = false
          @miq_server3.save!

          @miq_server1.monitor_servers
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload
          @miq_server3.reload
        end

        it "should migrate all roles properly" do
          expect(@miq_server3.active_role_names).to be_empty

          expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server2.active_role_names.include?("ems_operations")).to be_truthy

          expect(@miq_server1.active_role_names.include?("event")).not_to be_truthy
          expect(@miq_server2.active_role_names.include?("event")).to be_truthy

          expect(@miq_server1.active_role_names.include?("ems_metrics_coordinator")).to be_truthy
          expect(@miq_server2.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy

          expect(@miq_server1.active_role_names.include?("ems_inventory")).not_to be_truthy
          expect(@miq_server2.active_role_names.include?("ems_inventory")).to be_truthy
        end

        context "and then restarted" do
          before do
            @miq_server3.status = "started"
            @miq_server3.save!

            @miq_server1.monitor_servers
            @miq_server1.monitor_server_roles if @miq_server1.is_master?
            @miq_server2.reload
            @miq_server3.reload
          end

          it "should have all roles active after sync between them" do
            expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server2.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server3.active_role_names.include?("ems_operations")).to be_truthy

            expect(@miq_server1.active_role_names.include?("event")).not_to be_truthy
            expect(@miq_server2.active_role_names.include?("event")).to be_truthy
            expect(@miq_server3.active_role_names.include?("event")).not_to be_truthy

            expect(@miq_server1.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
            expect(@miq_server2.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
            expect(@miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy

            expect(@miq_server1.active_role_names.include?("ems_inventory")).not_to be_truthy
            expect(@miq_server2.active_role_names.include?("ems_inventory")).not_to be_truthy
            expect(@miq_server3.active_role_names.include?("ems_inventory")).to be_truthy
          end
        end
      end

      context "when Server2 is stopped" do
        before do
          @miq_server2.deactivate_all_roles
          @miq_server2.stopped_on = Time.now.utc
          @miq_server2.status = "stopped"
          @miq_server2.is_master = false
          @miq_server2.save!

          @miq_server1.monitor_servers
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload
          @miq_server3.reload
        end

        it "should have migrate all roles properly" do
          expect(@miq_server2.active_role_names).to be_empty

          expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server3.active_role_names.include?("ems_operations")).to be_truthy

          expect(@miq_server1.active_role_names.include?("event")).to be_truthy
          expect(@miq_server3.active_role_names.include?("event")).not_to be_truthy

          expect(@miq_server1.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
          expect(@miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy

          expect(@miq_server1.active_role_names.include?("ems_inventory")).not_to be_truthy
          expect(@miq_server3.active_role_names.include?("ems_inventory")).to be_truthy
        end

        context "and then restarted" do
          before do
            @miq_server2.status = "started"
            @miq_server2.save!

            @miq_server1.monitor_servers
            @miq_server1.monitor_server_roles if @miq_server1.is_master?
            @miq_server2.reload
            @miq_server3.reload
          end

          it "should have all roles active after sync between them" do
            expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server2.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server3.active_role_names.include?("ems_operations")).to be_truthy

            expect(@miq_server1.active_role_names.include?("event")).not_to be_truthy
            expect(@miq_server2.active_role_names.include?("event")).to be_truthy
            expect(@miq_server3.active_role_names.include?("event")).not_to be_truthy

            expect(@miq_server1.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
            expect(@miq_server2.active_role_names.include?("ems_metrics_coordinator")).not_to be_truthy
            expect(@miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy

            expect(@miq_server1.active_role_names.include?("ems_inventory")).not_to be_truthy
            expect(@miq_server2.active_role_names.include?("ems_inventory")).not_to be_truthy
            expect(@miq_server3.active_role_names.include?("ems_inventory")).to be_truthy
          end
        end
      end
    end

    context "with 3 Servers where I am the non-Master" do
      before do
        @miq_server1 = EvmSpecHelper.local_miq_server(:name => "Server 1")
        @miq_server1.deactivate_all_roles
        @miq_server1.role = 'event, ems_operations, ems_inventory'
        @miq_server1.activate_roles("ems_operations", "ems_inventory")

        @miq_server2 = FactoryBot.create(:miq_server, :is_master => true, :zone => @miq_server1.zone, :name => "Server 2")
        @miq_server2.deactivate_all_roles
        @miq_server2.role = 'event, ems_metrics_coordinator, ems_operations'
        @miq_server2.activate_roles("event", "ems_metrics_coordinator", 'ems_operations')

        @miq_server3 = FactoryBot.create(:miq_server, :zone => @miq_server2.zone, :name => "Server 3")
        @miq_server3.deactivate_all_roles
        @miq_server3.role = 'ems_metrics_coordinator, ems_inventory, ems_operations'
        @miq_server3.activate_roles("ems_operations")

        @miq_server1.monitor_servers
      end

      it "should have the master on Server 2" do
        expect(@miq_server1.is_master?).not_to be_truthy
        expect(@miq_server2.is_master?).to be_truthy
        expect(@miq_server3.is_master?).not_to be_truthy
      end

      it "should have all roles active after sync between them" do
        expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
        expect(@miq_server2.active_role_names.include?("ems_operations")).to be_truthy
        expect(@miq_server3.active_role_names.include?("ems_operations")).to be_truthy

        expect(@miq_server1.active_role_names.include?("event") ^ @miq_server2.active_role_names.include?("event")).to be_truthy
        expect(@miq_server2.active_role_names.include?("ems_metrics_coordinator") ^ @miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy
        expect(@miq_server1.active_role_names.include?("ems_inventory") ^ @miq_server3.active_role_names.include?("ems_inventory")).to be_truthy
      end

      context "where Master shuts down cleanly" do
        before do
          @miq_server2.deactivate_all_roles
          @miq_server2.stopped_on = Time.now.utc
          @miq_server2.status = "stopped"
          @miq_server2.is_master = false
          @miq_server2.save!

          @miq_server1.monitor_servers
        end

        it "should takeover as Master" do
          @miq_server2.reload
          @miq_server3.reload
          expect(@miq_server1.is_master?).to be_truthy
          expect(@miq_server2.is_master?).not_to be_truthy
          expect(@miq_server3.is_master?).not_to be_truthy
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload
          @miq_server3.reload

          expect(@miq_server1.inactive_roles.length).to eq(0)
          expect(@miq_server1.active_roles.length).to eq(3)

          expect(@miq_server2.server_roles.length).to eq(3)
          expect(@miq_server2.inactive_roles.length).to eq(3)
          expect(@miq_server2.active_roles.length).to eq(0)

          expect(@miq_server3.server_roles.length).to eq(3)
          expect(@miq_server3.inactive_roles.length).to eq(1)
          expect(@miq_server3.active_roles.length).to eq(2)

          expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.active_role_names.include?("event")).to be_truthy
          expect(@miq_server1.active_role_names.include?("ems_inventory")).to be_truthy
          expect(@miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy
        end
      end

      context "where Master is not responding" do
        before do
          Timecop.travel 5.minutes
          @miq_server1.monitor_servers
        end

        after do
          Timecop.return
        end

        it "should takeover as Master" do
          @miq_server2.reload
          @miq_server3.reload

          expect(@miq_server1.is_master?).to be_truthy
          expect(@miq_server2.is_master?).not_to be_truthy
          expect(@miq_server3.is_master?).not_to be_truthy
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload
          @miq_server3.reload

          expect(@miq_server2.status).to eq("not responding")
          expect(@miq_server2.server_roles.length).to eq(3)
          expect(@miq_server2.inactive_roles.length).to eq(3)
          expect(@miq_server2.active_roles.length).to eq(0)

          expect(@miq_server1.inactive_roles.length).to eq(0)
          expect(@miq_server1.active_roles.length).to eq(3)

          expect(@miq_server1.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.active_role_names.include?("event")).to be_truthy
          expect(@miq_server1.active_role_names.include?("ems_inventory")).to be_truthy
          expect(@miq_server3.active_role_names.include?("ems_metrics_coordinator")).to be_truthy
        end
      end
    end

    context "In 2 Zones," do
      before do
        @zone1 = FactoryBot.create(:zone)
        @zone2 = FactoryBot.create(:zone, :name => "zone2", :description => "Zone 2")
      end

      context "with 2 Servers across Zones where there is no master" do
        before do
          @miq_server1 = EvmSpecHelper.local_miq_server(:zone => @zone1, :name => "Server 1")
          @miq_server1.deactivate_all_roles

          @miq_server2 = FactoryBot.create(:miq_server, :guid => SecureRandom.uuid, :zone => @zone2, :name => "Server 2")
          @miq_server2.deactivate_all_roles
        end

        it "should allow only 1 Master in the Region" do
          @miq_server1.monitor_servers
          @miq_server2.reload
          expect(@miq_server1.is_master).to be_truthy
          expect(@miq_server2.is_master).to be_falsey

          @miq_server2.monitor_servers
          @miq_server2.reload
          expect(@miq_server1.is_master).to be_truthy
          expect(@miq_server2.is_master).to be_falsey
        end

        it "should allow only 1 Limited Regional Role in the Region" do
          @miq_server1.role    = 'event, ems_operations, scheduler, reporting'
          @miq_server2.role    = 'event, ems_operations, scheduler, reporting'

          @miq_server1.monitor_server_roles
          @miq_server2.reload

          expect(@miq_server1.active_role_names.include?("scheduler") && @miq_server2.active_role_names.include?("scheduler")).to be_falsey
          expect(@miq_server1.active_role_names.include?("scheduler") ^ @miq_server2.active_role_names.include?("scheduler")).to be_truthy
        end
      end

      context "with 2 Servers across Zones where I am the Master" do
        before do
          @miq_server1 = EvmSpecHelper.local_miq_server(:is_master => true, :zone => @zone1, :name => "Server 1")
          @miq_server1.deactivate_all_roles
          @roles1 = [['ems_operations', 1], ['event', 1], ['ems_metrics_coordinator', 2], ['scheduler', 1], ['reporting', 1]]
          @roles1.each { |role, priority| @miq_server1.assign_role(role, priority) }

          @miq_server2 = FactoryBot.create(:miq_server, :guid => SecureRandom.uuid, :zone => @zone2, :name => "Server 2")
          @miq_server2.deactivate_all_roles
          @roles2 = [['ems_operations', 1], ['event', 2], ['ems_metrics_coordinator', 1], ['scheduler', 2], ['reporting', 1]]
          @roles2.each { |role, priority| @miq_server2.assign_role(role, priority) }

          @miq_server1.monitor_server_roles
        end

        it "should have proper roles active after start" do
          expect(@miq_server1.server_roles.length).to eq(5)
          expect(@miq_server1.inactive_roles.length).to eq(0)
          expect(@miq_server1.active_roles.length).to eq(5)

          expect(@miq_server2.server_roles.length).to eq(5)
          expect(@miq_server2.inactive_roles.length).to eq(1)
          expect(@miq_server2.active_roles.length).to eq(4)

          expect(@miq_server1.active_role_names.include?("ems_operations") && @miq_server2.active_role_names.include?("ems_operations")).to be_truthy
          expect(@miq_server1.active_role_names.include?("event") && @miq_server2.active_role_names.include?("event")).to be_truthy
          expect(@miq_server1.active_role_names.include?("ems_metrics_coordinator") && @miq_server2.active_role_names.include?("ems_metrics_coordinator")).to be_truthy
          expect(@miq_server1.active_role_names.include?("reporting") && @miq_server2.active_role_names.include?("reporting")).to be_truthy
          expect(@miq_server1.active_role_names.include?("scheduler") && !@miq_server2.active_role_names.include?("scheduler")).to be_truthy
        end

        context "Server2 moved into zone of Server 1" do
          before do
            @miq_server2.zone = @zone1
            @miq_server2.save!
          end

          it "should resolve 1 Master in the Zone" do
            @miq_server1.monitor_servers
            @miq_server2.reload
            expect(@miq_server1.is_master?).to be_truthy
            expect(@miq_server2.is_master?).not_to be_truthy
          end

          it "should have proper roles after rezoning" do
            @miq_server1.monitor_server_roles
            @miq_server2.reload
            expect(@miq_server1.active_role_names.include?("ems_operations") && @miq_server2.active_role_names.include?("ems_operations")).to be_truthy
            expect(@miq_server1.active_role_names.include?("event") && !@miq_server2.active_role_names.include?("event")).to be_truthy
            expect(!@miq_server1.active_role_names.include?("ems_metrics_coordinator") && @miq_server2.active_role_names.include?("ems_metrics_coordinator")).to be_truthy
            expect(@miq_server1.active_role_names.include?("reporting") && @miq_server2.active_role_names.include?("reporting")).to be_truthy
            expect(@miq_server1.active_role_names.include?("scheduler") && !@miq_server2.active_role_names.include?("scheduler")).to be_truthy
          end
        end
      end
    end
  end
end
