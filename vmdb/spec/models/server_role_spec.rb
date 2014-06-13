require "spec_helper"

describe ServerRole do
  context "Without Seeding" do
    before(:each) do
      @server_roles = []
      [
        ['event',                   1],
        ['ems_metrics_coordinator', 1],
        ['ems_operations',          0]
      ].each { |r, max| @server_roles << FactoryGirl.create(:server_role, :name => r, :max_concurrent => max) }
    end

    it "validates uniqueness of name" do
      -> { FactoryGirl.create(:server_role, :name => @server_roles.first.name, :max_concurrent => @server_roles.first.max_concurrent)}.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should return all names" do
      @server_roles.collect {|s| s.name}.sort.should == ServerRole.all_names.sort
    end

    it "should respond to master_supported? properly" do
      @server_roles.each { |s| (s.max_concurrent == 1).should == s.master_supported? }
    end

    it "should respond to unlimited? properly" do
      @server_roles.each { |s| (s.max_concurrent == 0).should == s.unlimited? }
    end

  end

  context "With Seeding" do
    before(:each) do
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
    end

    it "should create proper number of rows" do
      (@csv.split("\n").length - 1).should == ServerRole.count
    end

    it "should import rows properly" do
      roles = @csv.split("\n")
      cols  = roles.shift
      roles.each do |role|
        next if role =~ /^#.*$/ # skip commented lines
        name, description, max_concurrent, external_failover, license_required, role_scope = role.split(',')
        max_concurrent = max_concurrent.to_i
        external_failover = true  if external_failover == 'true'
        external_failover = false if external_failover == 'false'
        sr = ServerRole.find_by_name(name)
        sr.description.should       == description
        sr.max_concurrent.should    == max_concurrent
        sr.external_failover.should == external_failover
        sr.license_required.should  == license_required
        sr.role_scope.should        == role_scope

        case max_concurrent
          when 0
            sr.unlimited?.should be_true
          when 1
            sr.master_supported?.should be_true
        end
      end
    end

  end
end
