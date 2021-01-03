RSpec.describe ServerRole do
  it "doesn't access database when unchanged model is saved" do
    m = described_class.create
    expect { m.valid? }.not_to make_database_queries
  end

  context "Without Seeding" do
    before do
      @server_roles = []
      [
        ['event',                   1],
        ['ems_metrics_coordinator', 1],
        ['ems_operations',          0]
      ].each { |r, max| @server_roles << FactoryBot.create(:server_role, :name => r, :max_concurrent => max) }
    end

    it "validates uniqueness of name" do
      expect { FactoryBot.create(:server_role, :name => @server_roles.first.name, :max_concurrent => @server_roles.first.max_concurrent) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "should return all names" do
      expect(@server_roles.collect(&:name).sort).to eq(ServerRole.all_names.sort)
    end

    it "should respond to master_supported? properly" do
      @server_roles.each { |s| expect(s.max_concurrent == 1).to eq(s.master_supported?) }
    end

    it "should respond to unlimited? properly" do
      @server_roles.each { |s| expect(s.max_concurrent == 0).to eq(s.unlimited?) }
    end
  end

  context "With Seeding" do
    before do
      @csv = <<-CSV.gsub(/^\s+/, "")
        name,description,max_concurrent,external_failover,role_scope
        automate,Automation Engine,0,false,region
        database_operations,Database Operations,0,false,region
        database_owner,Database Owner,1,false,database
        ems_inventory,Management System Inventory,1,false,zone
        ems_metrics_collector,Capacity & Utilization Data Collector,0,false,zone
        ems_metrics_coordinator,Capacity & Utilization Coordinator,1,false,zone
        ems_metrics_processor,Capacity & Utilization Data Processor,0,false,zone
        ems_operations,Management System Operations,0,false,zone
        event,Event Monitor,1,false,zone
        internet_connectivity,Internet Connectivity,0,false,region
        notifier,Alert Processor,1,false,region
        reporting,Reporting,0,false,region
        scheduler,Scheduler,1,false,region
        smartproxy,SmartProxy,0,false,zone
        smartstate,SmartState Analysis,0,false,zone
        user_interface,User Interface,0,false,region
        remote_console,Remote Consoles,0,false,region
        web_services,Web Services,0,false,region
      CSV

      allow(File).to receive(:open).and_return(StringIO.new(@csv))
      MiqRegion.seed
      ServerRole.seed
    end

    it "should create proper number of rows" do
      expect(@csv.split("\n").length - 1).to eq(ServerRole.count)
    end

    it "should import rows properly" do
      roles = @csv.split("\n")
      roles.shift
      roles.each do |role|
        next if role =~ /^#.*$/ # skip commented lines
        name, description, max_concurrent, external_failover, role_scope = role.split(',')
        max_concurrent = max_concurrent.to_i
        external_failover = true  if external_failover == 'true'
        external_failover = false if external_failover == 'false'
        sr = ServerRole.find_by(:name => name)
        expect(sr.description).to eq(description)
        expect(sr.max_concurrent).to eq(max_concurrent)
        expect(sr.external_failover).to eq(external_failover)
        expect(sr.role_scope).to eq(role_scope)

        case max_concurrent
        when 0
          expect(sr.unlimited?).to be_truthy
        when 1
          expect(sr.master_supported?).to be_truthy
        end
      end
    end
  end
end
