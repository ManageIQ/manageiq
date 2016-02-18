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
