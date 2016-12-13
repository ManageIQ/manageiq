describe EmsEvent do
  let(:data_dir) { File.join(File.dirname(__FILE__), 'event_data') }

  context ".add_vc" do
    before(:each) do
      @zone = FactoryGirl.create(:small_environment)
      @ems = @zone.ext_management_systems.first
      @host = @ems.hosts.first
      @vm1, @vm2 = @host.vms.sort_by(&:id)
    end

    it "with a GeneralUserEvent" do
      raw_event = YAML.load_file(File.join(data_dir, 'general_user_event.yml'))
      mock_raw_event_vm(raw_event)
      mock_raw_event_host(raw_event)

      EmsEvent.add_vc(@ems.id, raw_event)

      expect(EmsEvent.count).to eq(1)
      event = EmsEvent.first

      expect(event).to have_attributes(
        :event_type        => "GeneralUserEvent",
        :chain_id          => 5361104,
        :is_task           => false,
        :source            => "VC",
        :message           => "User logged event: EVM SmartState Analysis completed for VM [tch-UBUNTU-904-LTS-DESKTOP]",
        :timestamp         => Time.zone.parse("2010-08-24T01:08:10.396636Z"),
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
        raw_event = YAML.load_file(File.join(data_dir, 'event_ex.yml'))
        mock_raw_event_host(raw_event)

        EmsEvent.add_vc(@ems.id, raw_event)

        expect(EmsEvent.count).to eq(1)
        event = EmsEvent.first

        assert_result_fields(event)
        expect(event).to have_attributes(
          :event_type => "vprob.vmfs.resource.corruptondisk",
          :message    => "event.vprob.vmfs.resource.corruptondisk.fullFormat (vprob.vmfs.resource.corruptondisk)",
        )
      end

      it "without an eventTypeId" do
        raw_event = YAML.load_file(File.join(data_dir, 'event_ex_without_eventtypeid.yml'))
        mock_raw_event_host(raw_event)

        EmsEvent.add_vc(@ems.id, raw_event)

        expect(EmsEvent.count).to eq(1)
        event = EmsEvent.first

        assert_result_fields(event)
        expect(event).to have_attributes(
          :event_type => "EventEx",
          :message    => "",
        )
      end

      def assert_result_fields(event)
        expect(event).to have_attributes(
          :chain_id          => 297179,
          :is_task           => false,
          :source            => "VC",
          :timestamp         => Time.zone.parse("2010-11-12T17:15:42.661128Z"),
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
end
