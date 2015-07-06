require "spec_helper"

describe ChartsLayoutService do
  let(:host_openstack_infra) { FactoryGirl.create(:host_openstack_infra) }
  let(:host_redhat) { FactoryGirl.create(:host_redhat) }
  let(:vm_openstack) { FactoryGirl.create(:vm_openstack) }
  let(:host_openstack_infra_chart) do
    YAML::load(File.open(File.join(UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_perf_charts', 'HostOpenstackInfra') + '.yaml'))
  end
  let(:host_chart) do
    YAML::load(File.open(File.join(UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_perf_charts', 'Host') + '.yaml'))
  end
  let(:layout_chart) do
    YAML::load(File.open(File.join(UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_util_charts') + '.yaml'))
  end

  describe "#layout" do
    it "returns layout for specific class if exists" do
      chart = ChartsLayoutService.layout(host_openstack_infra,  UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_perf_charts', 'Host')
      chart.should == host_openstack_infra_chart
    end

    it "returns layout for fname if specific class does not exist" do
      chart = ChartsLayoutService.layout(host_redhat,  UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_perf_charts', 'Host')
      chart.should == host_chart
    end

    it "returns base layout if fname is missing" do
      chart = ChartsLayoutService.layout(host_openstack_infra,  UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_util_charts')
      chart.should == layout_chart
    end
  end

  describe "#layout applies_to_method functionality" do
    it "shows CPU (%) by default for VmOpenstack" do
      # By default percent is visible and mhz not
      chart = ChartsLayoutService.layout(vm_openstack,  UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_perf_charts', 'VmOrTemplate')
      chart.select { |x| x[:title] == "CPU (%)" }.count.should equal 1
      chart.select { |x| x[:title] == "CPU (Mhz)" }.count.should equal 0
    end

    it "shows CPU (Mhz) instead of CPU (%), when applies_to_method methods are changed" do
      # Stub it so mhz is visible and percent not
      vm_openstack.stub(:cpu_percent_available?).and_return(false)
      vm_openstack.stub(:cpu_mhz_available?).and_return(true)
      chart = ChartsLayoutService.layout(vm_openstack,  UiConstants::CHARTS_LAYOUTS_FOLDER, 'daily_perf_charts', 'VmOrTemplate')
      chart.select { |x| x[:title] == "CPU (%)" }.count.should equal 0
      chart.select { |x| x[:title] == "CPU (Mhz)" }.count.should equal 1
    end
  end
end
