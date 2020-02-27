describe ManageIQ::Reporting::Formatter::TimelineMessage do
  describe '#message_html on container event' do
    row = {}
    let(:ems) { FactoryBot.create(:ems_redhat, :id => 42) }
    let(:event) do
      FactoryBot.create(:ems_event,
                         :event_type            => 'CONTAINER_CREATED',
                         :ems_id                => 6,
                         :container_group_name  => 'hawkular-cassandra-1-wb1z6',
                         :container_namespace   => 'openshift-infra',
                         :container_name        => 'hawkular-cassandra-1',
                         :ext_management_system => ems)
    end

    flags = {:ems_cloud     => false,
             :ems_container => true,
             :time_zone     => nil}
    tests = {'event_type'                 => 'test timeline',
             'ext_management_system.name' => '<a href=/ems_container/42>test timeline</a>',
             'container_node_name'        => ''}

    tests.each do |column, href|
      it "Evaluate column #{column} content" do
        row[column] = 'test timeline'
        val = ManageIQ::Reporting::Formatter::TimelineMessage.new(row, event, flags, 'EmsEvent').message_html(column)
        expect(val).to eq(href)
      end
    end
  end

  describe '#message_html on vm event' do
    row = {}
    let(:vm) { FactoryBot.create(:vm_redhat, :id => 42) }
    let(:event) do
      FactoryBot.create(:ems_event,
                         :event_type     => 'VM_CREATED',
                         :vm_or_template => vm)
    end

    flags = {:ems_cloud     => false,
             :ems_container => false,
             :time_zone     => nil}
    tests = {'event_type'                 => 'test timeline',
             'ext_management_system.name' => '',
             'src_vm_name'                => '<a href=/vm/show/42>test timeline</a>'}

    tests.each do |column, href|
      it "Evaluate column #{column} content" do
        row[column] = 'test timeline'
        val = ManageIQ::Reporting::Formatter::TimelineMessage.new(row, event, flags, 'EmsEvent').message_html(column)
        expect(val).to eq(href)
      end
    end
  end

  describe '#message_html on policy event' do
    row = {}
    let(:vm) { FactoryBot.create(:vm_redhat, :id => 42, :name => 'Test VM') }
    let(:event) do
      FactoryBot.create(:policy_event,
                         :event_type   => 'vm_poweroff',
                         :target_id    => 42,
                         :target_name  => vm.name,
                         :target_class => 'VmOrTemplate')
    end

    tests = {'event_type'  => 'vm_poweroff',
             'target_name' => 'Test VM<br><b>VM or Template:</b>&nbsp;<a href=/vm_or_template/show/42>Test VM</a><br/><b>Assigned Profiles:</b>&nbsp;'}

    context 'policy profile assigned' do
      let(:event_content) { FactoryBot.create(:policy_event_content, :resource => policy_set) }
      let(:policy_set) { FactoryBot.create(:miq_policy_set) }

      before { event.contents << event_content }

      subject { ManageIQ::Reporting::Formatter::TimelineMessage.new({'event_type' => 'vm_poweroff'}, event, {}, 'PolicyEvent').message_html('target_name') }

      it 'generates a link to the affected policy profile' do
        is_expected.to include("?profile=#{policy_set.id}")
      end
    end

    tests.each do |column, href|
      it "Evaluate column #{column} content" do
        row[column] = 'vm_poweroff'
        val = ManageIQ::Reporting::Formatter::TimelineMessage.new(row, event, {}, 'PolicyEvent').message_html(column)
        expect(val).to eq(href)
      end
    end
  end

  describe '#events count for different categories' do
    let(:ems) { FactoryBot.create(:ems_redhat, :name => 'foobar') }

    def stub_ems_event(event_type)
      EventStream.new(:event_type => event_type, :ems_id => ems.id)
    end

    before do
      @report = FactoryBot.create(:miq_report,
                                   :db        => "EventStream",
                                   :col_order => %w(id name event_type timestamp),
                                   :headers   => %w(id name event_type timestamp),
                                   :timeline  => {:field => "EmsEvent-timestamp", :position => "Last"})
      @report.rpt_options = {:categories => {:power    => {:display_name => "Power Activity",
                                                           :include_set  => %w(VmPoweredOffEvent VmPoweredOnEvent),
                                                           :regexes      => []},
                                             :snapshot => {:display_name => "Snapshot Activity",
                                                           :include_set  => %w(AlarmCreatedEvent AlarmRemovedEvent),
                                                           :regexes      => []}}}

      data = []
      30.times do
        data.push(Ruport::Data::Record.new("id"         => stub_ems_event("VmPoweredOffEvent").id,
                                           "name"       => "Baz",
                                           "event_type" => "VmPoweredOffEvent",
                                           "timestamp"  => Time.zone.now))
      end

      15.times do
        data.push(Ruport::Data::Record.new("id"         => stub_ems_event("AlarmCreatedEvent").id,
                                           "name"       => "Baz",
                                           "event_type" => "AlarmCreatedEvent",
                                           "timestamp"  => Time.zone.now))
      end

      @report.table = Ruport::Data::Table.new(
        :column_names => %w(id name event_type timestamp),
        :data         => data
      )
    end

    it 'shows correct count of timeline events based on categories' do
      formatter = ManageIQ::Reporting::Formatter::Timeline.new
      formatter.options.mri = @report
      events = formatter.build_document_body
      expect(JSON.parse(events)[0]["data"][0].length).to eq(30)
      expect(JSON.parse(events)[1]["data"][0].length).to eq(15)
    end

    it 'shows correct count of timeline events together for report object with no categories' do
      @report.rpt_options = {}
      formatter = ManageIQ::Reporting::Formatter::Timeline.new
      formatter.options.mri = @report
      events = formatter.build_document_body
      expect(JSON.parse(events)[0]["data"][0].length).to eq(45)
    end

    it 'shows correct count of timeline events for timeline based report when rpt_options is nil' do
      @report.rpt_options = nil
      formatter = ManageIQ::Reporting::Formatter::Timeline.new
      formatter.options.mri = @report
      events = formatter.build_document_body
      expect(JSON.parse(events)[0]["data"][0].length).to eq(45)
    end
  end

  describe '#events count for regex categories' do
    let(:ems) { FactoryBot.create(:ems_redhat) }

    def stub_ems_event(event_type)
      EventStream.new(:event_type => event_type, :ems_id => ems.id)
    end

    before do
      @report = FactoryBot.create(
        :miq_report,
        :db        => "EventStream",
        :col_order => %w(id name event_type timestamp),
        :headers   => %w(id name event_type timestamp),
        :timeline  => {:field => "EmsEvent-timestamp", :position => "Last"}
      )
      @report.rpt_options = {
        :categories => {
          :power    => {
            :display_name => "Power Activity",
            :include_set  => [],
            :regexes      => [/Event$/]
          },
          :snapshot => {
            :display_name => "Snapshot Activity",
            :include_set  => %w(AlarmCreatedEvent AlarmRemovedEvent),
            :regexes      => []
          }
        }
      }

      data = []
      (1..5).each do |n|
        event_type = "VmPower#{n}Event"
        data.push(
          Ruport::Data::Record.new(
            "id"         => stub_ems_event(event_type).id,
            "name"       => "Baz",
            "event_type" => event_type,
            "timestamp"  => Time.zone.now
          )
        )
      end

      7.times do
        data.push(
          Ruport::Data::Record.new(
            "id"         => stub_ems_event("AlarmRemovedEvent").id,
            "name"       => "Baz",
            "event_type" => "AlarmRemovedEvent",
            "timestamp"  => Time.zone.now
          )
        )
      end

      @report.table = Ruport::Data::Table.new(
        :column_names => %w(id name event_type timestamp),
        :data         => data
      )
    end

    it 'shows correct count of timeline events based on categories' do
      formatter = ManageIQ::Reporting::Formatter::Timeline.new
      formatter.options.mri = @report
      events = formatter.build_document_body
      expect(JSON.parse(events)[0]["data"][0].length).to eq(5)
      expect(JSON.parse(events)[1]["data"][0].length).to eq(7)
    end

    it 'shows correct count of timeline events together for report object with no categories' do
      @report.rpt_options = {}
      formatter = ManageIQ::Reporting::Formatter::Timeline.new
      formatter.options.mri = @report
      events = formatter.build_document_body
      expect(JSON.parse(events)[0]["data"][0].length).to eq(12)
    end

    it 'shows correct count of timeline events for timeline based report when rpt_options is nil' do
      @report.rpt_options = nil
      formatter = ManageIQ::Reporting::Formatter::Timeline.new
      formatter.options.mri = @report
      events = formatter.build_document_body
      expect(JSON.parse(events)[0]["data"][0].length).to eq(12)
    end
  end
end

describe '#set data for headers that exist in col headers' do
  let(:ems) { FactoryBot.create(:ems_amazon) }

  def stub_ems_event(event_type)
    EventStream.create!(:event_type => event_type, :ems_id => ems.id)
  end

  before do
    @report = FactoryBot.create(:miq_report,
                                 :db        => "EventStream",
                                 :col_order => %w(id name event_type timestamp vm_location),
                                 :headers   => %w(id name event_type timestamp vm_location),
                                 :timeline  => {:field => "EmsEvent-timestamp", :position => "Last"})
    @report.rpt_options = {:categories => {:power    => {:display_name => "Power Activity",
                                                         :include_set  => %w(VmPoweredOffEvent VmPoweredOnEvent),
                                                         :regexes      => []},
                                           :snapshot => {:display_name => "Snapshot Activity",
                                                         :include_set  => %w(AlarmCreatedEvent AlarmRemovedEvent),
                                                         :regexes      => []}}}

    data = [Ruport::Data::Record.new("id"          => stub_ems_event("VmPoweredOffEvent").id,
                                     "name"        => "Baz",
                                     "event_type"  => "VmPoweredOffEvent",
                                     "vm_location" => "foo",
                                     "timestamp"   => Time.zone.now)]

    @report.table = Ruport::Data::Table.new(
      :column_names => %w(id name event_type timestamp vm_location),
      :data         => data
    )
  end

  it 'shows headers only if they exist in report col headers' do
    @report.rpt_options = nil
    formatter = ManageIQ::Reporting::Formatter::Timeline.new
    formatter.options.mri = @report
    events = formatter.build_document_body
    json = JSON.parse(events)[0]["data"][0][0]["event"]
    expect(json["vm_location"]["text"]).to eq("Source Instance Location")
    expect(json["vm_location"]["value"]).to eq("foo")
  end
end
