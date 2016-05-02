require 'spec_helper'

describe ReportFormatter::ReportTimeline do
  context '#bubble_icon' do
    def stub_bottleneck_event(resource_type, ems_type = nil)
      bottleneck_event = BottleneckEvent.create!(:resource_type => resource_type)
      unless ems_type.nil?
        ems = FactoryGirl.create(:ems_redhat)
        allow(ems).to receive(:emstype).and_return(ems_type)
        allow(bottleneck_event).to receive(:resource).and_return(ems)
      end
      bottleneck_event
    end

    it 'shows a generic icon for MiqEnterprise' do
      expect(ReportFormatter::ReportTimeline.new.bubble_icon(stub_bottleneck_event(MiqEnterprise))).to eq('enterprise')
    end

    it 'shows a generic icon for EmsCluster' do
      expect(ReportFormatter::ReportTimeline.new.bubble_icon(stub_bottleneck_event(EmsCluster))).to eq('cluster')
    end

    it 'shows a generic icon for ExtManagementSystem' do
      expect(ReportFormatter::ReportTimeline.new.bubble_icon(stub_bottleneck_event(ExtManagementSystem))).to eq('ems')
    end

    it 'shows a Red Hat logo for RHEVM EMS' do
      expect(ReportFormatter::ReportTimeline.new.bubble_icon(stub_bottleneck_event(ExtManagementSystem, 'rhevm'))).to eq('vendor-redhat')
    end
  end
end

describe ReportFormatter::TimelineMessage do
  describe '#message_html on container event' do
    row = {}
    let(:ems) { FactoryGirl.create(:ems_redhat, :id => 42) }
    let(:event) do
      FactoryGirl.create(:ems_event,
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
             'ext_management_system.name' => '<a href="/ems_container/42">test timeline</a>',
             'container_node_name'        => ''}

    tests.each do |column, href|
      it "Evaluate column #{column} content" do
        row[column] = 'test timeline'
        val = ReportFormatter::TimelineMessage.new.message_html(column, row, event, flags, 'EmsEvent')
        expect(val).to eq(href)
      end
    end
  end

  describe '#message_html on vm event' do
    row = {}
    let(:vm) { FactoryGirl.create(:vm_redhat, :id => 42) }
    let(:event) do
      FactoryGirl.create(:ems_event,
                         :event_type     => 'VM_CREATED',
                         :vm_or_template => vm)
    end

    flags = {:ems_cloud     => false,
             :ems_container => false,
             :time_zone     => nil}
    tests = {'event_type'                 => 'test timeline',
             'ext_management_system.name' => '',
             'src_vm_name'                => '<a href="/vm/show/42">test timeline</a>'}

    tests.each do |column, href|
      it "Evaluate column #{column} content" do
        row[column] = 'test timeline'
        val = ReportFormatter::TimelineMessage.new.message_html(column, row, event, flags, 'EmsEvent')
        expect(val).to eq(href)
      end
    end
  end

  describe '#message_html on bottleneck event' do
    row = {}
    let(:ems_cluster) { FactoryGirl.create(:ems_cluster, :id => 42, :name => 'Test Cluster') }
    let(:event) do
      FactoryGirl.create(:bottleneck_event,
                         :event_type    => 'MemoryUsage',
                         :resource_id   => 42,
                         :resource_name => ems_cluster.name,
                         :resource_type => 'EmsCluster')
    end

    tests = {'event_type'    => 'MemoryUsage',
             'resource_name' => '<a href="/ems_cluster/show/42">Test Cluster</a>'}

    tests.each do |column, href|
      it "Evaluate column #{column} content" do
        row[column] = 'MemoryUsage'
        val = ReportFormatter::TimelineMessage.new.message_html(column, row, event, {}, 'BottleneckEvent')
        expect(val).to eq(href)
      end
    end
  end
end
