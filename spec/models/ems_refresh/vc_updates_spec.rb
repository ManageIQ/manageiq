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
      expect(@vm.send(meth)).to eq(expected)
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
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary.runtime.powerState")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary.runtime")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary")).to be_truthy

      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary.runtime.power")).to be_falsey
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary.run")).to be_falsey
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "sum")).to be_falsey

      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000].backing.compatibilityMode"))
        .to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000].backing")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000]")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device")).to be_truthy

      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.device[2000].back")).to be_falsey
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.hardware.dev")).to be_falsey

      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.extraConfig[\"vmsafe.enable\"].key")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.extraConfig[\"vmsafe.enable\"]")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "config.extraConfig")).to be_truthy

      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary.guest")).to be_truthy
      expect(EmsRefresh::VcUpdates.selected_property?(:vm, "summary.guest.disk")).to be_falsey

      expect(EmsRefresh::VcUpdates.selected_property?(:other, "does.not.matter")).to be_falsey
    end
  end
end
