describe Metric::LongTermAverages do
  context ".get_averages_over_time_period" do
    let(:ems_openshift) do
      FactoryGirl.create(:ems_openshift, :hostname => 't', :port => 8443, :name => 't',
                         :zone => Zone.first)
    end
    let(:c1) { FactoryGirl.create(:container_group) }
    let(:c2) { FactoryGirl.create(:container_image) }

    it "it does not collect live metrics unless object is valid and ems is taged" do
      ems_openshift.container_groups << [c1]
      ems_openshift.container_images << [c2]

      expect(Metric::LongTermAverages.live_report?(ems_openshift)).to eq(false)
      expect(Metric::LongTermAverages.live_report?(c1)).to eq(false)
      expect(Metric::LongTermAverages.live_report?(c2)).to eq(false)
    end

    it "it will collect live metrics if object is valid and ems is taged" do
      ems_openshift.container_groups << [c1]
      ems_openshift.container_images << [c2]
      ems_openshift.tag_with("/live_reports/use_hawkular", :ns => "/managed")

      expect(Metric::LongTermAverages.live_report?(ems_openshift)).to eq(true)
      expect(Metric::LongTermAverages.live_report?(c1)).to eq(true)
      expect(Metric::LongTermAverages.live_report?(c2)).to eq(false)
    end
  end
end
