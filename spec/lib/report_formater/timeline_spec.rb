require 'spec_helper'

describe ReportFormatter::ReportTimeline do
  context '#bubble_icon' do
    def stub_bottleneck_event(resource_type, ems_type = nil)
      BottleneckEvent.create!(:resource_type => resource_type)
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
  end
end
