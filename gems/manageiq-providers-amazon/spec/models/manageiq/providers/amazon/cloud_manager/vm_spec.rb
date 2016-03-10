require_relative '../aws_helper'

describe ManageIQ::Providers::Amazon::CloudManager::Vm do
  let(:ems)                   { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:vm)                    { FactoryGirl.create(:vm_perf_amazon, :ext_management_system => ems) }

  context "#is_available?" do
    let(:power_state_on)        { "running" }
    let(:power_state_suspended) { "pending" }

    context("with :start") do
      let(:state) { :start }
      include_examples "Vm operation is available when not powered on"
    end

    context("with :stop") do
      let(:state) { :stop }
      include_examples "Vm operation is available when powered on"
    end

    context("with :suspend") do
      let(:state) { :suspend }
      include_examples "Vm operation is not available"
    end

    context("with :pause") do
      let(:state) { :pause }
      include_examples "Vm operation is not available"
    end

    context("with :shutdown_guest") do
      let(:state) { :shutdown_guest }
      include_examples "Vm operation is not available"
    end

    context("with :standby_guest") do
      let(:state) { :standby_guest }
      include_examples "Vm operation is not available"
    end

    context("with :reboot_guest") do
      let(:state) { :reboot_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :reset") do
      let(:state) { :reset }
      include_examples "Vm operation is not available"
    end
  end

  describe "#set_custom_field" do
    it "updates a tag on an instance" do
      stubbed_responses = {
        :ec2 => {
          :describe_instances =>
            { :reservations => [{instances: [:instance_id => vm.ems_ref]}] }
        }
      }
      with_aws_stubbed(stubbed_responses) do
        expect(vm.set_custom_field('tag_key', 'tag_value')).to be_truthy
      end
    end
  end
end
