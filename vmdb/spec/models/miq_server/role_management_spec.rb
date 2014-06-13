require "spec_helper"

describe "Server Role Management" do

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
      @server_roles = ServerRole.all
      @zone         = FactoryGirl.create(:zone)
      @miq_server   = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone, :status => "started", :name => "Server 1")
      MiqServer.my_server(true)
      @miq_server.deactivate_all_roles
    end

    context "role=" do
      it "normal case" do
        @miq_server.assign_role('ems_operations', 1)
        @miq_server.server_role_names.should == ['ems_operations']

        desired = 'event,scheduler,user_interface'
        @miq_server.role = desired
        @miq_server.server_role_names.should == desired.split(",")
      end

      it "with a duplicate existing role" do
        @miq_server.assign_role('ems_operations', 1)

        desired = 'ems_operations,ems_operations,scheduler'
        @miq_server.role = desired
        @miq_server.server_role_names.should == %w{ ems_operations scheduler }
      end

      it "with duplicate new roles" do
        @miq_server.assign_role('event', 1)

        desired = 'ems_operations,scheduler,scheduler'
        @miq_server.role = desired
        @miq_server.server_role_names.should == %w{ ems_operations scheduler }
      end
    end

    it "should assign role properly when requested" do
      @roles = [ ['ems_operations', 1], ['event', 2], ['ems_metrics_coordinator', 1], ['scheduler', 1], ['reporting', 1] ]
      @roles.each do |role, priority|
        asr = @miq_server.assign_role(role, priority)
        asr.priority.should == priority
        asr.server_role.name.should == role
      end
    end
  end
end
