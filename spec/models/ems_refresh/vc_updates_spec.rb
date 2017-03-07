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
end
