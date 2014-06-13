require "spec_helper"

describe EmsEvent do
  context ".add_vc" do
    DATA_DIR = Rails.root.join("spec", "models", "ems_event", "parsers", "data")

    before(:each) do
      @zone = FactoryGirl.create(:small_environment)
      @ems = @zone.ext_management_systems.first
      @host = @ems.hosts.first
      @vm1, @vm2 = @host.vms.sort_by(&:id)
    end

    it "with a GeneralUserEvent" do
      raw_event = YAML.load_file(File.join(DATA_DIR, 'general_user_event.yml'))
      mock_raw_event_vm(raw_event)
      mock_raw_event_host(raw_event)

      EmsEvent.add_vc(@ems.id, raw_event)

      EmsEvent.count.should == 1
      event = EmsEvent.first

      event.should have_attributes(
        :event_type        => "GeneralUserEvent",
        :chain_id          => 5361104,
        :is_task           => false,
        :source            => "VC",
        :message           => "User logged event: EVM SmartState Analysis completed for VM [tch-UBUNTU-904-LTS-DESKTOP]",
        :timestamp         => Time.parse("2010-08-24T01:08:10.396636Z"),
        :username          => "MANAGEIQ\\thennessy",

        :ems_id            => @ems.id,
        :vm_or_template_id => @vm1.id,
        :vm_name           => @vm1.name,
        :vm_location       => @vm1.location,
        :host_id           => @host.id,
        :host_name         => @host.hostname,
      )
    end

    context "with an EventEx event" do
      it "with an eventTypeId" do
        raw_event = YAML.load_file(File.join(DATA_DIR, 'event_ex.yml'))
        mock_raw_event_host(raw_event)

        EmsEvent.add_vc(@ems.id, raw_event)

        EmsEvent.count.should == 1
        event = EmsEvent.first

        assert_result_fields(event)
        event.should have_attributes(
          :event_type => "vprob.vmfs.resource.corruptondisk",
          :message    => "event.vprob.vmfs.resource.corruptondisk.fullFormat (vprob.vmfs.resource.corruptondisk)",
        )
      end

      it "without an eventTypeId" do
        raw_event = YAML.load_file(File.join(DATA_DIR, 'event_ex_without_eventtypeid.yml'))
        mock_raw_event_host(raw_event)

        EmsEvent.add_vc(@ems.id, raw_event)

        EmsEvent.count.should == 1
        event = EmsEvent.first

        assert_result_fields(event)
        event.should have_attributes(
          :event_type => "EventEx",
          :message    => "",
        )
      end

      def assert_result_fields(event)
        event.should have_attributes(
          :chain_id          => 297179,
          :is_task           => false,
          :source            => "VC",
          :timestamp         => Time.parse("2010-11-12T17:15:42.661128Z"),
          :username          => nil,

          :ems_id            => @ems.id,
          :vm_or_template_id => nil,
          :vm_name           => nil,
          :vm_location       => nil,
          :host_id           => @host.id,
          :host_name         => @host.hostname,
        )
      end
    end

    def mock_raw_event_host(raw_event)
      raw_event["host"]["host"] = @host.ems_ref_obj
      raw_event["host"]["name"] = @host.hostname
    end

    def mock_raw_event_vm(raw_event)
      raw_event["vm"]["vm"]     = @vm1.ems_ref_obj
      raw_event["vm"]["name"]   = @vm1.name
      raw_event["vm"]["path"]   = @vm1.location
    end
  end

  context "with availability zones" do
    before :each do
      @zone = FactoryGirl.create(:small_environment)
      @ems  = @zone.ext_management_systems.first
      @vm = FactoryGirl.create(:vm_openstack, :ems_ref => "vm1")
      @availability_zone = FactoryGirl.create(:availability_zone_openstack, :ems_ref => "az1")
    end

    context ".process_availability_zone_in_event!" do
      before :each do
        @event_hash = {
          :vm_or_template_id => @vm.id
        }
      end

      context "when the event has an availability zone" do
        before :each do
          @event_hash[:availability_zone_ems_ref] = @availability_zone.ems_ref
        end

        it "should use the availability zone from the event" do
          EmsEvent.process_availability_zone_in_event!(@event_hash)
          @event_hash[:availability_zone_id].should eq @availability_zone.id
        end
      end

      context "when the event has no availability zone" do
        context "and the VM has an availability zone" do
          before :each do
            @vm.availability_zone_id = @availability_zone.id
            @vm.save
          end

          it "should use the VM's availability zone" do
            EmsEvent.process_availability_zone_in_event!(@event_hash)
            @event_hash[:availability_zone_id].should eq @availability_zone.id
          end
        end

        context "and the VM does not have an availability zone" do
          it "should not put an availability zone in the event hash" do
            EmsEvent.process_availability_zone_in_event!(@event_hash)
            @event_hash[:availability_zone_id].should be_nil
          end
        end
      end
    end

    context ".add" do
      before :each do
        @event_hash = {
          :event_type => "event_with_availability_zone",
          :vm_ems_ref => @vm.ems_ref,
          :timestamp  => Time.now,
          :ems_id     => @ems.id
        }
      end

      context "when the event does not have an availability zone" do
        it "should create an event record with the VMs availability zone" do
          @vm.availability_zone_id = @availability_zone.id
          @vm.save

          new_event = EmsEvent.add(@vm.ems_id, @event_hash)
          new_event.availability_zone_id.should eq @availability_zone.id
        end
      end

      context "when the event does contain an availability zone" do
        it "should use the availability zone from the event" do
          @event_hash[:availability_zone_ems_ref] = @availability_zone.ems_ref
          @vm.availability_zone_id = nil
          @vm.save

          new_event = EmsEvent.add(@vm.ems_id, @event_hash)
          new_event.availability_zone_id.should eq @availability_zone.id
        end
      end
    end

    context "#purge_queue" do
      let(:purge_time) { (Time.now + 10).round }

      before(:each) do
        EvmSpecHelper.seed_for_miq_queue
        described_class.purge_queue(purge_time)
      end

      it "with nothing in the queue" do
        q = MiqQueue.all
        q.length.should == 1
        q.first.should have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge",
          :args        => [purge_time]
        )
      end

      it "with item already in the queue" do
        new_purge_time = (Time.now + 20).round
        described_class.purge_queue(new_purge_time)

        q = MiqQueue.all
        q.length.should == 1
        q.first.should have_attributes(
          :class_name  => described_class.name,
          :method_name => "purge",
          :args        => [new_purge_time]
        )
      end
    end

    context ".purge" do
      let(:purge_date) { 2.weeks.ago }

      before do
        @old_event        = FactoryGirl.create(:ems_event, :timestamp => purge_date - 1.day)
        @purge_date_event = FactoryGirl.create(:ems_event, :timestamp => purge_date)
        @new_event        = FactoryGirl.create(:ems_event, :timestamp => purge_date + 1.day)
      end

      def assert_delete_calls_and_unpurged_ids(options)
        described_class.should_receive(:delete_all).public_send(options[:delete_calls]).and_call_original
        described_class.purge(purge_date, options[:window], options[:limit])
        described_class.order(:id).pluck(:id).should == Array(options[:unpurged_ids]).sort
      end

      it "purge_date and older" do
        assert_delete_calls_and_unpurged_ids(
          :delete_calls => :once,
          :unpurged_ids => @new_event.id
        )
      end

      it "with a window" do
        assert_delete_calls_and_unpurged_ids(
          :delete_calls => :twice,
          :unpurged_ids => @new_event.id,
          :window       => 1
        )
      end

      it "with a limit" do
        assert_delete_calls_and_unpurged_ids(
          :delete_calls => :once,
          :unpurged_ids => [@purge_date_event.id, @new_event.id],
          :window       => nil,
          :limit        => 1
        )
      end

      it "with window > limit" do
        assert_delete_calls_and_unpurged_ids(
          :delete_calls => :once,
          :unpurged_ids => [@purge_date_event.id, @new_event.id],
          :window       => 2,
          :limit        => 1
        )
      end

      it "with limit > window" do
        assert_delete_calls_and_unpurged_ids(
          :delete_calls => :twice,
          :unpurged_ids => @new_event.id,
          :window       => 1,
          :limit        => 2
        )
      end
    end
  end
end
