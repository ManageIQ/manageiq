require "spec_helper"

describe EmsRefresh::VcUpdates do
  context "handling Vm updates" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => FactoryGirl.create(:ems_vmware))
      @prop = {
        :op      => "update",
        :objType => "VirtualMachine",
        :mor     => @vm.ems_ref_obj
      }
    end

    it "will handle summary.runtime.powerState" do
      @prop.merge!(
        :changedProps => ["summary.runtime.powerState"],
        :changeSet    => [{"name" => "summary.runtime.powerState", "op" => "assign"}]
      )

      assert_vm_property_updated("poweredOn",  :power_state, "on")
      assert_vm_property_updated("poweredOff", :power_state, "off")

      @vm.update_attribute(:template, true)
      assert_vm_property_updated("poweredOn",  :power_state, "never")
      assert_vm_property_updated("poweredOff", :power_state, "never")
    end

    it "will handle summary.config.template" do
      @prop.merge!(
        :changedProps => ["summary.config.template"],
        :changeSet    => [{"name" => "summary.config.template", "op" => "assign"}]
      )

      assert_vm_property_updated("true",  :template?, true)
      assert_vm_property_updated("false", :template?, false)
    end

    def assert_vm_property_updated(prop_value, meth, expected)
      @prop[:changeSet].first["val"] = prop_value
      EmsRefresh.vc_update(@vm.ems_id, @prop)
      @vm = VmOrTemplate.find(@vm.id) # reload will not handle vm <=> template type change, so we must do a real find
      @vm.send(meth).should == expected
    end
  end

  it ".selected_property?" do
    EmsRefresh::VcUpdates.with_constants(
      :VIM_SELECTOR_SPEC => {
        :ems_refresh_vm => [
          "config.extraConfig[*].key",
          "config.hardware.device[*].backing.compatibilityMode",
          "summary.guest.hostName",
          "summary.runtime.powerState"
        ]
      }
    ) do
      EmsRefresh::VcUpdates.selected_property?(:vm, "summary.runtime.powerState").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "summary.runtime").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "summary").should be_true

      EmsRefresh::VcUpdates.selected_property?(:vm, "summary.runtime.power").should be_false
      EmsRefresh::VcUpdates.selected_property?(:vm, "summary.run").should be_false
      EmsRefresh::VcUpdates.selected_property?(:vm, "sum").should be_false

      EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000].backing.compatibilityMode").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000].backing").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000]").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device").should be_true

      EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000].back").should be_false
      EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.dev").should be_false

      EmsRefresh::VcUpdates.selected_property?(:vm, "config.extraConfig[\"vmsafe.enable\"].key").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "config.extraConfig[\"vmsafe.enable\"]").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "config.extraConfig").should be_true

      EmsRefresh::VcUpdates.selected_property?(:vm, "summary.guest").should be_true
      EmsRefresh::VcUpdates.selected_property?(:vm, "summary.guest.disk").should be_false

      EmsRefresh::VcUpdates.selected_property?(:other, "does.not.matter").should be_false
    end
  end
end
