require "spec_helper"

describe MiqWorker do
  context ".has_required_role?" do
    def check_has_required_role(worker_role_names, expected_result)
      described_class.stub(:required_roles).and_return(worker_role_names)
      described_class.has_required_role?.should == expected_result
    end

    before(:each) do
      @server_active_role_names = ["foo", "bar"]
      @server = FactoryGirl.create(:miq_server, :zone => FactoryGirl.create(:zone))
      MiqServer.stub(:my_server).and_return(@server)
      @server.stub(:active_role_names).and_return(@server_active_role_names)
    end

    context "clean_active_messages" do
      before do
        MiqWorker.any_instance.stub(:set_command_line)
        @worker = FactoryGirl.create(:miq_worker, :miq_server => @server)
        @message = FactoryGirl.create(:miq_queue, :handler => @worker, :state => 'dequeue')
      end

      it "normal" do
        @worker.active_messages.length.should == 1
        @worker.clean_active_messages
        @worker.reload.active_messages.length.should == 0
      end

      it "invokes a message callback" do
        @message.update_attribute(:miq_callback, {:class_name => 'Kernel', :method_name => 'rand'})
        Kernel.should_receive(:rand)
        @worker.clean_active_messages
      end
    end

    it "when worker roles is nil" do
      check_has_required_role(nil, true)
    end

    context "when worker roles is a string" do
      it "that is blank" do
        check_has_required_role(" ", true)
      end

      it "that is one of the server roles" do
        check_has_required_role("foo", true)
      end

      it "that is not one of the server roles" do
        check_has_required_role("baa", false)
      end
    end

    context "when worker roles is an array" do
      it "that is empty" do
        check_has_required_role([], true)
      end

      it "that is a subset of server roles" do
        check_has_required_role(["foo"], true)
        check_has_required_role(["bah", "foo"], true)
      end

      it "that is not a subset of server roles" do
        check_has_required_role(["bah"], false)
      end
    end
  end

  context ".workers_configured_count" do
    before(:each) do
      @configured_count = 2
      described_class.stub(:worker_settings).and_return({:count => @configured_count})
      @maximum_workers_count = described_class.maximum_workers_count
    end

    after(:each) do
      described_class.maximum_workers_count = @maximum_workers_count
    end

    it "when maximum_workers_count is nil" do
      described_class.workers_configured_count.should == @configured_count
    end

    it "when maximum_workers_count is less than configured_count" do
      described_class.maximum_workers_count = 1
      described_class.workers_configured_count.should == 1
    end

    it "when maximum_workers_count is equal to the configured_count" do
      described_class.maximum_workers_count = 2
      described_class.workers_configured_count.should == @configured_count
    end

    it "when maximum_workers_count is greater than configured_count" do
      described_class.maximum_workers_count = 2
      described_class.workers_configured_count.should == @configured_count
    end
  end

  context "with two servers" do
    before(:each) do
      described_class.stub(:nice_increment).and_return("+10")

      @zone = FactoryGirl.create(:zone)
      @server = FactoryGirl.create(:miq_server, :zone => @zone)
      MiqServer.stub(:my_server).and_return(@server)
      @worker = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => @server)

      @server2 = FactoryGirl.create(:miq_server, :zone => @zone)
      @worker2 = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server => @server2)
    end

    it ".server_scope" do
      described_class.server_scope.all.should == [@worker]
    end

    it ".server_scope with a different server" do
      described_class.server_scope(@server2.id).all.should == [@worker2]
    end

    it ".server_scope after already scoping on a different server" do
      described_class.send(:with_scope, :find => described_class.where(:miq_server_id => @server2.id)) do
        described_class.server_scope.all.should == [@worker2]
        described_class.server_scope(@server.id).all.should == [@worker2]
      end
    end

    context "worker_settings" do
      before do
        @config1 = {
          :workers => {
            :worker_base => {
              :defaults => {:count => 1},
              :queue_worker_base => {
                :defaults => {:count => 3},
                :ems_refresh_worker => {:count => 5}
              }
            }
          }
        }

        @config2 = {
          :workers => {
            :worker_base => {
              :defaults => {:count => 2},
              :queue_worker_base => {
                :defaults => {:count => 4},
                :ems_refresh_worker => {:count => 6}
              }
            }
          }
        }
        @server.stub(:get_config).with("vmdb").and_return(@config1)
        @server2.stub(:get_config).with("vmdb").and_return(@config2)
      end

      context "#worker_settings" do
        it "uses the worker's server" do
          @worker.worker_settings[:count].should  == 5
          @worker2.worker_settings[:count].should == 6
        end

        it "uses passed in config" do
          @worker.worker_settings(:config => @config2)[:count].should   == 6
          @worker2.worker_settings(:config => @config1)[:count].should  == 5
        end

        it "uses closest parent's defaults" do
          @config1[:workers][:worker_base][:queue_worker_base][:ems_refresh_worker].delete(:count)
          @worker.worker_settings[:count].should  == 3
        end
      end

      context ".worker_settings" do
        it "uses MiqServer.my_server" do
          MiqEmsRefreshWorker.worker_settings[:count].should == 5
        end

        it "uses passed in config" do
          MiqEmsRefreshWorker.worker_settings(:config => @config2)[:count].should == 6
        end
      end
    end
  end

  context "instance" do
    before(:each) do
      described_class.stub(:nice_increment).and_return("+10")
      @worker = FactoryGirl.create(:miq_worker)
    end

    it "is_current? false when starting" do
      @worker.update_attribute(:status, described_class::STATUS_STARTING)
      @worker.is_current?.should_not be_true
    end

    it "is_current? true when started" do
      @worker.update_attribute(:status, described_class::STATUS_STARTED)
      @worker.is_current?.should be_true
    end

    it "is_current? true when working" do
      @worker.update_attribute(:status, described_class::STATUS_WORKING)
      @worker.is_current?.should be_true
    end
  end
end
