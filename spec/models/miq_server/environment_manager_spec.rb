require "spec_helper"

describe "Server Environment Management" do
  context ".spartan_mode" do
    before(:each) { MiqServer.class_eval { instance_variable_set :@spartan_mode, nil } }
    after(:each) { MiqServer.class_eval { instance_variable_set :@spartan_mode, nil } }

    it "when ENV['MIQ_SPARTAN'] is not set" do
      ENV.stub(:[]).with('MIQ_SPARTAN').and_return(nil)
      MiqServer.spartan_mode.should be_blank
    end

    it "when ENV['MIQ_SPARTAN'] is set" do
      spartan = "minimal:foo:bar"
      ENV.stub(:[]).with('MIQ_SPARTAN').and_return(spartan)
      MiqServer.spartan_mode.should == spartan
    end
  end

  context ".minimal_env?" do
    it "when spartan_mode is 'minimal'" do
      MiqServer.stub(:spartan_mode).and_return("minimal")
      MiqServer.minimal_env?.should be_true
    end

    it "when spartan_mode starts with 'minimal'" do
      MiqServer.stub(:spartan_mode).and_return("minimal:foo:bar")
      MiqServer.minimal_env?.should be_true
    end

    it "when spartan_mode does not start with 'minimal'" do
      MiqServer.stub(:spartan_mode).and_return("foo:bar")
      MiqServer.minimal_env?.should be_false
    end
  end

  context ".normal_env?" do
    it "when minimal_env? is true" do
      MiqServer.stub(:minimal_env?).and_return(true)
      MiqServer.normal_env?.should be_false
    end

    it "when minimal_env? is false" do
      MiqServer.stub(:minimal_env?).and_return(false)
      MiqServer.normal_env?.should be_true
    end
  end

  context ".minimal_env_options" do
    before(:each) { MiqServer.class_eval { instance_variable_set :@minimal_env_options, nil } }
    after(:each) { MiqServer.class_eval { instance_variable_set :@minimal_env_options, nil } }

    it "when spartan_mode is 'minimal'" do
      MiqServer.stub(:spartan_mode).and_return("minimal")
      MiqServer.minimal_env_options.should == []
    end

    it "when spartan_mode starts with 'minimal' and has various roles" do
      MiqServer.stub(:spartan_mode).and_return("minimal:foo:bar")
      MiqServer.minimal_env_options.should == %w(foo bar)
    end

    it "when spartan_mode starts with 'minimal' and has various roles, including netbeans" do
      MiqServer.stub(:spartan_mode).and_return("minimal:foo:netbeans:bar")
      MiqServer.minimal_env_options.should == %w(foo schedule reporting noui bar)
    end

    it "when spartan_mode does not start with 'minimal'" do
      MiqServer.stub(:spartan_mode).and_return("foo:bar")
      MiqServer.minimal_env_options.should == []
    end
  end

  context ".startup_mode" do
    context "when minimal_env? is true" do
      before(:each) { MiqServer.stub(:minimal_env?).and_return(true) }

      it "when minimal_env_options is empty" do
        MiqServer.stub(:minimal_env_options).and_return([])
        MiqServer.startup_mode.should == "Minimal"
      end

      it "when minimal_env_options is not empty" do
        minimal_env_options = %w(foo bar)
        MiqServer.stub(:minimal_env_options).and_return(minimal_env_options)
        MiqServer.startup_mode.should == "Minimal [#{minimal_env_options.join(', ')}]"
      end
    end

    it "when minimal_env? is false" do
      MiqServer.stub(:minimal_env?).and_return(false)
      MiqServer.startup_mode.should == "Normal"
    end
  end

  context "#check_disk_usage" do
    before do
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone
      @miq_server.stub(:disk_usage_threshold => 70)
    end

    it "normal usage" do
      expect(@miq_server.check_disk_usage([:used_bytes_percent => 50]))
      expect(MiqQueue.count).to eql 0
    end

    it "database disk exceeds usage" do
      disks = [{:used_bytes_percent => 85, :mount_point => '/var/lib/pgsql/data'}]
      expect(@miq_server.check_disk_usage(disks))
      queue = MiqQueue.first

      expect(queue.args[1]).to eql 'evm_server_db_disk_high_usage'
      expect(queue.args[2][:event_details]).to include disks.first[:mount_point]
    end
  end
end
