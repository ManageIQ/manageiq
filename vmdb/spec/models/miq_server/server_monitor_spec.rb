require "spec_helper"

describe "Server Monitor" do

  context "After Setup," do
    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)

      @csv = <<-CSV.gsub(/^\s+/, "")
        name,description,max_concurrent,external_failover,license_required,role_scope
        automate,Automation Engine,0,false,automate,region
        database_operations,Database Operations,0,false,,region
        database_owner,Database Owner,1,false,,database
        database_synchronization,Database Synchronization,1,false,,region
        ems_inventory,Management System Inventory,1,false,,zone
        ems_metrics_collector,Capacity & Utilization Data Collector,0,false,,zone
        ems_metrics_coordinator,Capacity & Utilization Coordinator,1,false,,zone
        ems_metrics_processor,Capacity & Utilization Data Processor,0,false,,zone
        ems_operations,Management System Operations,0,false,,zone
        event,Event Monitor,1,false,,zone
        notifier,Alert Processor,1,false,,region
        reporting,Reporting,0,false,,region
        scheduler,Scheduler,1,false,,region
        smartproxy,SmartProxy,0,false,,zone
        smartstate,SmartState Analysis,0,false,,zone
        storage_inventory,Storage Inventory,1,false,,zone
        user_interface,User Interface,0,false,,region
        web_services,Web Services,0,false,,region
      CSV
      ServerRole.stub(:seed_data).and_return(@csv)
      MiqRegion.seed
      ServerRole.seed

      # Do this manually, to avoid caching at the class level
      ServerRole.stub(:database_owner).and_return(ServerRole.find_by_name('database_owner'))

      @server_roles = ServerRole.all
    end

    it "should respond properly to UI helper methods" do
      @server_roles.each do |server_role|
        server_role.unlimited?.should be_true        if server_role.max_concurrent == 0
        server_role.master_supported?.should be_true if server_role.max_concurrent == 1
        ServerRole.to_role(server_role).should      == server_role
        ServerRole.to_role(server_role.name).should == server_role
      end
    end

    context "with 1 Server" do
      before(:each) do
        @zone       = FactoryGirl.create(:zone)
        @miq_server = FactoryGirl.create(:miq_server_not_master, :guid => @guid, :zone => @zone)
        MiqServer.my_server(true)
        @miq_server.monitor_servers

        @miq_server.deactivate_all_roles
        @miq_server.role    = 'event, ems_operations, scheduler, reporting'
      end

      it "should have no roles active after start" do
        @miq_server.server_roles.length.should   == 4
        @miq_server.inactive_roles.length.should == 4
        @miq_server.active_roles.length.should   == 0
      end

      it "should activate unlimited zone role via activate_in_zone method" do
        rolename = "ems_operations"
        @miq_server.assigned_server_roles.each { |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_zone
        }
        @miq_server.reload
        @miq_server.inactive_roles.length.should    == 3
        @miq_server.active_role_names.length.should == 1
        @miq_server.active_role_names.include?(rolename).should be_true
        @miq_server.inactive_role_names.include?(rolename).should_not be_true
      end

      it "should activate limited zone role via activate_in_zone method" do
        rolename = "event"
        @miq_server.assigned_server_roles.each { |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_zone
        }
        @miq_server.reload
        @miq_server.inactive_roles.length.should    == 3
        @miq_server.active_role_names.length.should == 1
        @miq_server.active_role_names.include?(rolename).should be_true
        @miq_server.inactive_role_names.include?(rolename).should_not be_true
      end

      it "should activate unlimited region role via activate_in_region method" do
        rolename = "reporting"
        @miq_server.assigned_server_roles.each { |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_region
        }
        @miq_server.reload
        @miq_server.inactive_roles.length.should    == 3
        @miq_server.active_role_names.length.should == 1
        @miq_server.active_role_names.include?(rolename).should be_true
        @miq_server.inactive_role_names.include?(rolename).should_not be_true
      end

      it "should activate limited region role via activate_in_region method" do
        rolename = "scheduler"
        @miq_server.assigned_server_roles.each { |asr|
          next unless asr.server_role.name == rolename
          asr.activate_in_region
        }
        @miq_server.reload
        @miq_server.inactive_roles.length.should    == 3
        @miq_server.active_role_names.length.should == 1
        @miq_server.active_role_names.include?(rolename).should be_true
        @miq_server.inactive_role_names.include?(rolename).should_not be_true
      end

      context "after initial monitor_servers" do
        before(:each) do
          @miq_server.monitor_server_roles
        end

        it "should have all roles active after monitor_servers" do
          @miq_server.active_role_names.length.should == 4
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
        end

        it "should deactivate unlimited role via deactivate_in_zone method" do
          rolename = "ems_operations"
          @miq_server.assigned_server_roles.each { |asr|
            next unless asr.server_role.name == rolename
            asr.deactivate_in_zone
          }
          @miq_server.reload
          @miq_server.inactive_roles.length.should    == 1
          @miq_server.active_role_names.length.should == 3
          @miq_server.active_role_names.include?(rolename).should_not be_true
          @miq_server.inactive_role_names.include?(rolename).should be_true
        end

        it "should deactivate limited role via deactivate_in_zone method" do
          rolename = "event"
          @miq_server.assigned_server_roles.each { |asr|
            next unless asr.server_role.name == rolename
            asr.deactivate_in_zone
          }
          @miq_server.reload
          @miq_server.inactive_roles.length.should    == 1
          @miq_server.active_role_names.length.should == 3
          @miq_server.active_role_names.include?(rolename).should_not be_true
          @miq_server.inactive_role_names.include?(rolename).should be_true
        end

        it "should activate newly assigned unlimited zone role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, smartstate'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 5
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
          @miq_server.active_role_names.include?("smartstate").should be_true
        end

        it "should activate newly assigned limited zone role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, ems_inventory'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 5
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
          @miq_server.active_role_names.include?("ems_inventory").should be_true
        end

        it "should activate newly assigned unlimited region role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, database_operations'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 5
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
          @miq_server.active_role_names.include?("database_operations").should be_true
        end

        it "should activate newly assigned limited region role" do
          @miq_server.role = 'event, ems_operations, scheduler, reporting, database_synchronization'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 5
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
          @miq_server.active_role_names.include?("database_synchronization").should be_true
        end

        it "should deactivate removed unlimited zone role" do
          @miq_server.role = 'event, scheduler, reporting'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 3
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
        end

        it "should deactivate removed limited zone role" do
          @miq_server.role = 'ems_operations, scheduler, reporting'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 3
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
        end

        it "should deactivate removed unlimited region role" do
          @miq_server.role = 'event, ems_operations, scheduler'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 3
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("scheduler").should be_true
        end

        it "should deactivate removed limited region role" do
          @miq_server.role = 'event, ems_operations, reporting'
          @miq_server.monitor_server_roles
          @miq_server.active_role_names.length.should == 3
          @miq_server.active_role_names.include?("event").should be_true
          @miq_server.active_role_names.include?("ems_operations").should be_true
          @miq_server.active_role_names.include?("reporting").should be_true
        end
      end
    end

    context "with 2 Servers in 2 Zones where I am the Master" do
      before(:each) do
        @zone        = FactoryGirl.create(:zone)

        @miq_server1 = FactoryGirl.create(:miq_server_not_master, :guid => @guid,            :zone => @zone, :is_master => true)
        @miq_server1.deactivate_all_roles
        @miq_server1.role = 'event, ems_operations, scheduler, reporting'

        @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :is_master => false)
        @miq_server2.deactivate_all_roles
        @miq_server2.role = 'event, ems_operations, scheduler, reporting'
      end

      it "should have no roles active after start" do
        @miq_server1.server_roles.length.should   == 4
        @miq_server1.inactive_roles.length.should == 4
        @miq_server1.active_roles.length.should   == 0

        @miq_server2.server_roles.length.should   == 4
        @miq_server2.inactive_roles.length.should == 4
        @miq_server2.active_roles.length.should   == 0
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
        @miq_server1.inactive_roles.length.should    == 3
        @miq_server1.active_role_names.length.should == 1
        @miq_server1.active_role_names.include?(rolename).should be_true

        @miq_server2.inactive_roles.length.should    == 3
        @miq_server2.active_role_names.length.should == 1
        @miq_server2.active_role_names.include?(rolename).should be_true
      end

      context "after monitor_servers" do
        before(:each) do
          @miq_server1.monitor_server_roles
          @miq_server2.reload
        end

        it "should have all roles active after sync between them" do
          (@miq_server1.active_role_names.include?("ems_operations")        && @miq_server2.active_role_names.include?("ems_operations")).should be_true
          (@miq_server1.active_role_names.include?("event")                  ^ @miq_server2.active_role_names.include?("event")).should be_true
          (@miq_server1.active_role_names.include?("reporting")             && @miq_server2.active_role_names.include?("reporting")).should be_true
          (@miq_server1.active_role_names.include?("scheduler")              ^ @miq_server2.active_role_names.include?("scheduler")).should be_true
        end
      end

      context "with Non-Master having the active roles" do
        before(:each) do
          @miq_server2.activate_roles("event")
          @miq_server1.monitor_server_roles
        end

        it "should have all roles on the desired servers" do
          (@miq_server1.active_role_names.include?("ems_operations")           && @miq_server2.active_role_names.include?("ems_operations")).should be_true
          (@miq_server1.inactive_role_names.include?("event")                  && @miq_server2.active_role_names.include?("event")).should be_true
        end

        context "where Non-Master shuts down cleanly" do
          before(:each) do
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
            @miq_server1.active_role_names.include?("ems_operations").should be_true
            @miq_server1.active_role_names.include?("event").should be_true
            @miq_server2.active_role_names.should be_empty
          end
        end

        context "where Non-Master is not responding" do
          before(:each) do
            @miq_server1.monitor_servers
            Timecop.travel 5.minutes
            @miq_server1.monitor_servers
            Timecop.return
          end

          it "should mark server as not responding" do
            @miq_server2.reload.status.should == "not responding"
          end

          it "should migrate roles to Master" do
            @miq_server1.monitor_server_roles
            @miq_server2.reload

            @miq_server2.server_roles.length.should   == 4
            @miq_server2.inactive_roles.length.should == 4
            @miq_server2.active_roles.length.should   == 0

            @miq_server1.server_roles.length.should   == 4
            @miq_server1.inactive_roles.length.should == 0
            @miq_server1.active_roles.length.should   == 4

            @miq_server1.active_role_names.include?("ems_operations").should be_true
            @miq_server1.active_role_names.include?("event").should be_true
            @miq_server1.active_role_names.include?("reporting").should be_true
            @miq_server1.active_role_names.include?("scheduler").should be_true
          end
        end

      end
    end

    context "with 2 Servers where I am the non-Master" do
      before(:each) do
        @zone        = FactoryGirl.create(:zone)
        @miq_server1 = FactoryGirl.create(:miq_server_not_master, :guid => @guid,            :zone => @zone, :is_master => false)
        MiqServer.my_server(true)
        @miq_server1.deactivate_all_roles
        @miq_server1.role         = 'event, ems_operations, scheduler, reporting'
        @roles1 = [ ['ems_operations', 1], ['event', 2], ['scheduler', 2], ['reporting', 1] ]
        @roles1.each { |role, priority| @miq_server1.assign_role(role, priority) }
        @miq_server1.activate_roles("ems_operations", 'reporting')

        @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :is_master => true)
        @miq_server2.deactivate_all_roles
        @miq_server2.role         = 'event, ems_operations, scheduler, reporting'
        @roles2 = [ ['ems_operations', 1], ['event', 1], ['scheduler', 1], ['reporting', 1] ]
        @roles2.each { |role, priority| @miq_server2.assign_role(role, priority) }
        @miq_server2.activate_roles("event", "ems_operations", 'scheduler', 'reporting')

        @miq_server1.monitor_servers
      end

      it "should have all roles active after sync between them" do
        (@miq_server1.active_role_names.include?("ems_operations")        && @miq_server2.active_role_names.include?("ems_operations")).should be_true
        (@miq_server1.active_role_names.include?("event")                  ^ @miq_server2.active_role_names.include?("event")).should be_true
        (@miq_server1.active_role_names.include?("reporting")             && @miq_server2.active_role_names.include?("reporting")).should be_true
        (@miq_server1.active_role_names.include?("scheduler")              ^ @miq_server2.active_role_names.include?("scheduler")).should be_true
      end

      context "where Master shuts down cleanly" do
        before(:each) do
          @miq_server2.deactivate_all_roles
          @miq_server2.stopped_on = Time.now.utc
          @miq_server2.status = "stopped"
          @miq_server2.is_master = false
          @miq_server2.save!
          @miq_server1.monitor_servers
        end

        it "should takeover as Master" do
          @miq_server1.is_master?.should be_true
          @miq_server2.reload
          @miq_server2.is_master?.should_not be_true
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server1.active_role_names.include?("ems_operations").should be_true
          @miq_server1.active_role_names.include?("event").should be_true
          @miq_server1.active_role_names.include?("reporting").should be_true
          @miq_server1.active_role_names.include?("scheduler").should be_true
          @miq_server2.reload
          @miq_server2.active_role_names.should be_empty
        end

      end

      context "where Master is not responding" do
        before(:each) do
          Timecop.travel 5.minutes
          @miq_server1.monitor_servers
        end

        after(:each) do
          Timecop.return
        end

        it "should takeover as Master" do
          @miq_server1.is_master?.should be_true
          @miq_server2.reload
          @miq_server2.is_master?.should_not be_true
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload

          @miq_server2.status.should == "not responding"
          @miq_server2.server_roles.length.should   == 4
          @miq_server2.inactive_roles.length.should == 4
          @miq_server2.active_roles.length.should   == 0

          @miq_server1.inactive_roles.length.should == 0
          @miq_server1.active_roles.length.should   == 4
          @miq_server1.active_role_names.include?("database_owner").should be_false

          @miq_server1.active_role_names.include?("ems_operations").should be_true
          @miq_server1.active_role_names.include?("event").should be_true
          @miq_server1.active_role_names.include?("reporting").should be_true
          @miq_server1.active_role_names.include?("scheduler").should be_true
        end
      end
    end

    context "with 3 Servers where I am the Master" do
      before(:each) do
        @zone        = FactoryGirl.create(:zone)
        @miq_server1 = FactoryGirl.create(:miq_server_not_master, :guid => @guid,            :zone => @zone, :name => "Miq1", :is_master => true)
        MiqServer.my_server(true)
        @miq_server1.deactivate_all_roles
        @roles1 = [ ['ems_operations', 2], ['event', 2], ['ems_inventory', 3], ['ems_metrics_coordinator', 2], ]
        @roles1.each { |role, priority| @miq_server1.assign_role(role, priority) }

        @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :name => "Miq2", :is_master => false)
        @miq_server2.deactivate_all_roles
        @roles2 = [ ['ems_operations', 1], ['event', 1], ['ems_metrics_coordinator', 3], ['ems_inventory', 2],  ]
        @roles2.each { |role, priority| @miq_server2.assign_role(role, priority) }

        @miq_server3 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :name => "Miq3", :is_master => false)
        @miq_server3.deactivate_all_roles
        @roles3 = [ ['ems_operations', 2], ['event', 3], ['ems_inventory', 1], ['ems_metrics_coordinator', 1] ]
        @roles3.each { |role, priority| @miq_server3.assign_role(role, priority) }

        @miq_server1.monitor_servers
        @miq_server1.monitor_server_roles if @miq_server1.is_master?
        @miq_server2.reload
        @miq_server3.reload
      end

      it "should have all roles active after sync between them" do
        @miq_server1.active_role_names.include?("ems_operations").should be_true
        @miq_server2.active_role_names.include?("ems_operations").should be_true
        @miq_server3.active_role_names.include?("ems_operations").should be_true

        @miq_server1.active_role_names.include?("event").should_not be_true
        @miq_server2.active_role_names.include?("event").should be_true
        @miq_server3.active_role_names.include?("event").should_not be_true

        @miq_server1.active_role_names.include?("ems_metrics_coordinator").should_not be_true
        @miq_server2.active_role_names.include?("ems_metrics_coordinator").should_not be_true
        @miq_server3.active_role_names.include?("ems_metrics_coordinator").should be_true

        @miq_server1.active_role_names.include?("ems_inventory").should_not be_true
        @miq_server2.active_role_names.include?("ems_inventory").should_not be_true
        @miq_server3.active_role_names.include?("ems_inventory").should be_true
      end

      it "should respond to helper methods for UI" do
        @miq_server1.is_master_for_role?("ems_operations").should_not be_true
        @miq_server2.is_master_for_role?("ems_operations").should be_true
        @miq_server3.is_master_for_role?("ems_operations").should_not be_true

        @miq_server1.is_master_for_role?("event").should_not be_true
        @miq_server2.is_master_for_role?("event").should be_true
        @miq_server3.is_master_for_role?("event").should_not be_true

        @miq_server1.is_master_for_role?("ems_inventory").should_not be_true
        @miq_server2.is_master_for_role?("ems_inventory").should_not be_true
        @miq_server3.is_master_for_role?("ems_inventory").should be_true

        @miq_server1.is_master_for_role?("ems_metrics_coordinator").should_not be_true
        @miq_server2.is_master_for_role?("ems_metrics_coordinator").should_not be_true
        @miq_server3.is_master_for_role?("ems_metrics_coordinator").should be_true
      end

      context "when Server3 is stopped" do
        before(:each) do
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
          @miq_server3.active_role_names.should be_empty

          @miq_server1.active_role_names.include?("ems_operations").should be_true
          @miq_server2.active_role_names.include?("ems_operations").should be_true

          @miq_server1.active_role_names.include?("event").should_not be_true
          @miq_server2.active_role_names.include?("event").should be_true

          @miq_server1.active_role_names.include?("ems_metrics_coordinator").should be_true
          @miq_server2.active_role_names.include?("ems_metrics_coordinator").should_not be_true

          @miq_server1.active_role_names.include?("ems_inventory").should_not be_true
          @miq_server2.active_role_names.include?("ems_inventory").should be_true
        end

        context "and then restarted" do
          before(:each) do
            @miq_server3.status = "started"
            @miq_server3.save!

            @miq_server1.monitor_servers
            @miq_server1.monitor_server_roles if @miq_server1.is_master?
            @miq_server2.reload
            @miq_server3.reload
          end

          it "should have all roles active after sync between them" do
            @miq_server1.active_role_names.include?("ems_operations").should be_true
            @miq_server2.active_role_names.include?("ems_operations").should be_true
            @miq_server3.active_role_names.include?("ems_operations").should be_true

            @miq_server1.active_role_names.include?("event").should_not be_true
            @miq_server2.active_role_names.include?("event").should be_true
            @miq_server3.active_role_names.include?("event").should_not be_true

            @miq_server1.active_role_names.include?("ems_metrics_coordinator").should_not be_true
            @miq_server2.active_role_names.include?("ems_metrics_coordinator").should_not be_true
            @miq_server3.active_role_names.include?("ems_metrics_coordinator").should be_true

            @miq_server1.active_role_names.include?("ems_inventory").should_not be_true
            @miq_server2.active_role_names.include?("ems_inventory").should_not be_true
            @miq_server3.active_role_names.include?("ems_inventory").should be_true
          end
        end
      end

      context "when Server2 is stopped" do
        before(:each) do
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
          @miq_server2.active_role_names.should be_empty

          @miq_server1.active_role_names.include?("ems_operations").should be_true
          @miq_server3.active_role_names.include?("ems_operations").should be_true

          @miq_server1.active_role_names.include?("event").should be_true
          @miq_server3.active_role_names.include?("event").should_not be_true

          @miq_server1.active_role_names.include?("ems_metrics_coordinator").should_not be_true
          @miq_server3.active_role_names.include?("ems_metrics_coordinator").should be_true

          @miq_server1.active_role_names.include?("ems_inventory").should_not be_true
          @miq_server3.active_role_names.include?("ems_inventory").should be_true
        end

        context "and then restarted" do
          before(:each) do
            @miq_server2.status = "started"
            @miq_server2.save!

            @miq_server1.monitor_servers
            @miq_server1.monitor_server_roles if @miq_server1.is_master?
            @miq_server2.reload
            @miq_server3.reload
          end

          it "should have all roles active after sync between them" do
            @miq_server1.active_role_names.include?("ems_operations").should be_true
            @miq_server2.active_role_names.include?("ems_operations").should be_true
            @miq_server3.active_role_names.include?("ems_operations").should be_true

            @miq_server1.active_role_names.include?("event").should_not be_true
            @miq_server2.active_role_names.include?("event").should be_true
            @miq_server3.active_role_names.include?("event").should_not be_true

            @miq_server1.active_role_names.include?("ems_metrics_coordinator").should_not be_true
            @miq_server2.active_role_names.include?("ems_metrics_coordinator").should_not be_true
            @miq_server3.active_role_names.include?("ems_metrics_coordinator").should be_true

            @miq_server1.active_role_names.include?("ems_inventory").should_not be_true
            @miq_server2.active_role_names.include?("ems_inventory").should_not be_true
            @miq_server3.active_role_names.include?("ems_inventory").should be_true
          end
        end
      end

    end

    context "with 3 Servers where I am the non-Master" do
      before(:each) do
        @zone        = FactoryGirl.create(:zone)
        @miq_server1 = FactoryGirl.create(:miq_server_not_master, :guid => @guid,            :zone => @zone, :name => "Server 1", :is_master => false)
        MiqServer.my_server(true)
        @miq_server1.deactivate_all_roles
        @miq_server1.role         = 'event, ems_operations, ems_inventory'
        @miq_server1.activate_roles("ems_operations", "ems_inventory")

        @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :name => "Server 2", :is_master => true)
        @miq_server2.deactivate_all_roles
        @miq_server2.role         = 'event, ems_metrics_coordinator, ems_operations'
        @miq_server2.activate_roles("event", "ems_metrics_coordinator", 'ems_operations')

        @miq_server3 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :name => "Server 3", :is_master => false)
        @miq_server3.deactivate_all_roles
        @miq_server3.role         = 'ems_metrics_coordinator, ems_inventory, ems_operations'
        @miq_server3.activate_roles("ems_operations")

        @miq_server1.monitor_servers
      end

      it "should have the master on Server 2" do
        @miq_server1.is_master?.should_not be_true
        @miq_server2.is_master?.should be_true
        @miq_server3.is_master?.should_not be_true
      end

      it "should have all roles active after sync between them" do
        @miq_server1.active_role_names.include?("ems_operations").should be_true
        @miq_server2.active_role_names.include?("ems_operations").should be_true
        @miq_server3.active_role_names.include?("ems_operations").should be_true

        (@miq_server1.active_role_names.include?("event")                  ^ @miq_server2.active_role_names.include?("event")).should be_true
        (@miq_server2.active_role_names.include?("ems_metrics_coordinator") ^ @miq_server3.active_role_names.include?("ems_metrics_coordinator")).should be_true
        (@miq_server1.active_role_names.include?("ems_inventory")          ^ @miq_server3.active_role_names.include?("ems_inventory")).should be_true
      end

      context "where Master shuts down cleanly" do
        before(:each) do
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
          @miq_server1.is_master?.should be_true
          @miq_server2.is_master?.should_not be_true
          @miq_server3.is_master?.should_not be_true
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload
          @miq_server3.reload

          @miq_server1.inactive_roles.length.should == 0
          @miq_server1.active_roles.length.should   == 3

          @miq_server2.server_roles.length.should   == 3
          @miq_server2.inactive_roles.length.should == 3
          @miq_server2.active_roles.length.should   == 0

          @miq_server3.server_roles.length.should   == 3
          @miq_server3.inactive_roles.length.should == 1
          @miq_server3.active_roles.length.should   == 2

          @miq_server1.active_role_names.include?("ems_operations").should be_true
          @miq_server1.active_role_names.include?("event").should be_true
          @miq_server1.active_role_names.include?("ems_inventory").should be_true
          @miq_server3.active_role_names.include?("ems_metrics_coordinator").should be_true
        end
      end

      context "where Master is not responding" do
        before(:each) do
          Timecop.travel 5.minutes
          @miq_server1.monitor_servers
        end

        after(:each) do
          Timecop.return
        end

        it "should takeover as Master" do
          @miq_server2.reload
          @miq_server3.reload

          @miq_server1.is_master?.should be_true
          @miq_server2.is_master?.should_not be_true
          @miq_server3.is_master?.should_not be_true
        end

        it "should migrate roles to Master" do
          @miq_server1.monitor_server_roles if @miq_server1.is_master?
          @miq_server2.reload
          @miq_server3.reload

          @miq_server2.status.should == "not responding"
          @miq_server2.server_roles.length.should   == 3
          @miq_server2.inactive_roles.length.should == 3
          @miq_server2.active_roles.length.should   == 0

          @miq_server1.inactive_roles.length.should == 0
          @miq_server1.active_roles.length.should   == 3

          @miq_server1.active_role_names.include?("ems_operations").should be_true
          @miq_server1.active_role_names.include?("event").should be_true
          @miq_server1.active_role_names.include?("ems_inventory").should be_true
          @miq_server3.active_role_names.include?("ems_metrics_coordinator").should be_true
        end

      end

    end

    context "In 2 Zones," do
      before(:each) do
        @zone1 = FactoryGirl.create(:zone)
        @zone2 = FactoryGirl.create(:zone, :name => "zone2", :description => "Zone 2")
      end

      context "with 2 Servers across Zones where there is no master" do
        before(:each) do

          @miq_server1 = FactoryGirl.create(:miq_server_not_master, :guid => @guid,            :zone => @zone1, :status => "started", :name => "Server 1")
          MiqServer.my_server(true)
          @miq_server1.deactivate_all_roles

          @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone2, :status => "started", :name => "Server 2")
          @miq_server2.deactivate_all_roles
        end

        it "should allow only 1 Master in the Region" do
          @miq_server1.monitor_servers
          @miq_server2.reload
          @miq_server1.is_master.should be_true
          @miq_server2.is_master.should be_false

          @miq_server2.monitor_servers
          @miq_server2.reload
          @miq_server1.is_master.should be_true
          @miq_server2.is_master.should be_false
        end

        it "should allow only 1 Limited Regional Role in the Region" do
          @miq_server1.role    = 'event, ems_operations, scheduler, reporting'
          @miq_server2.role    = 'event, ems_operations, scheduler, reporting'

          @miq_server1.monitor_server_roles
          @miq_server2.reload

          (@miq_server1.active_role_names.include?("scheduler") && @miq_server2.active_role_names.include?("scheduler")).should be_false
          (@miq_server1.active_role_names.include?("scheduler") ^  @miq_server2.active_role_names.include?("scheduler")).should be_true
        end
      end

      context "with 2 Servers across Zones where I am the Master" do
        before(:each) do
          @miq_server1 = FactoryGirl.create(:miq_server_not_master, :guid => @guid,            :zone => @zone1, :status => "started", :name => "Server 1", :is_master => true)
          MiqServer.my_server(true)
          @miq_server1.deactivate_all_roles
          @roles1 = [ ['ems_operations', 1], ['event', 1], ['ems_metrics_coordinator', 2], ['scheduler', 1], ['reporting', 1] ]
          @roles1.each { |role, priority| @miq_server1.assign_role(role, priority) }

          @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone2, :status => "started", :name => "Server 2", :is_master => false)
          @miq_server2.deactivate_all_roles
          @roles2 = [ ['ems_operations', 1], ['event', 2], ['ems_metrics_coordinator', 1], ['scheduler', 2], ['reporting', 1] ]
          @roles2.each { |role, priority| @miq_server2.assign_role(role, priority) }

          @miq_server1.monitor_server_roles
        end

        it "should have proper roles active after start" do
          @miq_server1.server_roles.length.should   == 5
          @miq_server1.inactive_roles.length.should == 0
          @miq_server1.active_roles.length.should   == 5

          @miq_server2.server_roles.length.should   == 5
          @miq_server2.inactive_roles.length.should == 1
          @miq_server2.active_roles.length.should   == 4

          (@miq_server1.active_role_names.include?("ems_operations")         &&  @miq_server2.active_role_names.include?("ems_operations")).should be_true
          (@miq_server1.active_role_names.include?("event")                  &&  @miq_server2.active_role_names.include?("event")).should be_true
          (@miq_server1.active_role_names.include?("ems_metrics_coordinator") &&  @miq_server2.active_role_names.include?("ems_metrics_coordinator")).should be_true
          (@miq_server1.active_role_names.include?("reporting")              &&  @miq_server2.active_role_names.include?("reporting")).should be_true
          (@miq_server1.active_role_names.include?("scheduler")              && !@miq_server2.active_role_names.include?("scheduler")).should be_true
        end

        context "Server2 moved into zone of Server 1" do
          before(:each) do
            @miq_server2.zone = @zone1
            @miq_server2.save!
          end

          it "should resolve 1 Master in the Zone" do
            @miq_server1.monitor_servers
            @miq_server2.reload
            @miq_server1.is_master?.should be_true
            @miq_server2.is_master?.should_not be_true
          end

          it "should have proper roles after rezoning" do
            @miq_server1.monitor_server_roles
            @miq_server2.reload
            ( @miq_server1.active_role_names.include?("ems_operations")         &&  @miq_server2.active_role_names.include?("ems_operations")).should be_true
            ( @miq_server1.active_role_names.include?("event")                  && !@miq_server2.active_role_names.include?("event")).should be_true
            (!@miq_server1.active_role_names.include?("ems_metrics_coordinator") &&  @miq_server2.active_role_names.include?("ems_metrics_coordinator")).should be_true
            ( @miq_server1.active_role_names.include?("reporting")              &&  @miq_server2.active_role_names.include?("reporting")).should be_true
            ( @miq_server1.active_role_names.include?("scheduler")              && !@miq_server2.active_role_names.include?("scheduler")).should be_true
          end

        end
      end
    end
  end

end
