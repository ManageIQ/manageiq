describe EmsRefresh::SaveInventory do
  context "save_vms_inventory handling duplicate uids" do
    before(:each) do
      @zone = FactoryGirl.create(:zone)
      @ems  = FactoryGirl.create(:ems_vmware, :zone => @zone)
    end

    context "with no dups in the database" do
      before(:each) do
        @vm1 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
        @vm2 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
      end

      it "should handle no dups in the raw data" do
        data = raw_data_without_dups(@vm1, @vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(2)
        v1, v2 = vms.sort_by(&:id)

        expect(v1.id).to eq(@vm1.id)
        expect(v1.uid_ems).to eq(@vm1.uid_ems)

        expect(v2.id).to eq(@vm2.id)
        expect(v2.uid_ems).to eq(@vm2.uid_ems)
      end

      it "should handle dups in the raw data" do
        data = raw_data_with_dups(@vm1, @vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(3)

        disconnected, connected = vms.partition { |v| v.ems_id.nil? }
        expect(disconnected.length).to eq(1)
        expect(connected.length).to eq(2)

        d      = disconnected.first
        c1, c2 = connected.sort_by(&:id)

        expect(d.id).to eq(@vm2.id)
        expect(d.uid_ems).to eq(@vm2.uid_ems)

        expect(c1.id).to eq(@vm1.id)
        expect(c1.uid_ems).to eq(@vm1.uid_ems)

        expect(c2.id).not_to eq(@vm1.id)
        expect(c2.id).not_to eq(@vm2.id)
        expect(c2.uid_ems).to eq(@vm1.uid_ems)
      end
    end

    context "with dups in the database" do
      before(:each) do
        @uid = MiqUUID.new_guid
        @vm1 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems, :uid_ems => @uid)
        @vm2 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems, :uid_ems => @uid)
      end

      it "should handle no dups in the raw data" do
        data = raw_data_without_dups(@vm1, @vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(3)

        disconnected, connected = vms.partition { |v| v.ems_id.nil? }
        expect(disconnected.length).to eq(1)
        expect(connected.length).to eq(2)

        d      = disconnected.first
        c1, c2 = connected.sort_by(&:id)

        expect(d.id).to eq(@vm2.id)
        expect(d.uid_ems).to eq(@vm2.uid_ems)

        expect(c1.id).to eq(@vm1.id)
        expect(c1.uid_ems).to eq(@vm1.uid_ems)

        expect(c2.id).not_to eq(@vm1.id)
        expect(c2.id).not_to eq(@vm2.id)
        expect(c2.uid_ems).not_to eq(@vm1.uid_ems)
      end

      it "should handle dups in the raw data" do
        data = raw_data_with_dups(@vm1, @vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(2)
        v1, v2 = vms.sort_by(&:id)

        expect(v1.id).to eq(@vm1.id)
        expect(v1.uid_ems).to eq(@vm1.uid_ems)

        expect(v2.id).to eq(@vm2.id)
        expect(v2.uid_ems).to eq(@vm2.uid_ems)
      end
    end

    context "with disconnected dups in the database" do
      before(:each) do
        @uid = MiqUUID.new_guid
        @vm1 = FactoryGirl.create(:vm_with_ref, :ext_management_system => nil,  :uid_ems => @uid)
        @vm2 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems, :uid_ems => @uid)
      end

      it "should handle no dups in the raw data" do
        data = raw_data_without_dups(@vm1, @vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(3)

        disconnected, connected = vms.partition { |v| v.ems_id.nil? }
        expect(disconnected.length).to eq(1)
        expect(connected.length).to eq(2)

        d      = disconnected.first
        c1, c2 = connected.sort_by(&:id)

        expect(d.id).to eq(@vm2.id)
        expect(d.uid_ems).to eq(@vm2.uid_ems)

        expect(c1.id).to eq(@vm1.id)
        expect(c1.uid_ems).to eq(@vm1.uid_ems)

        expect(c2.id).not_to eq(@vm1.id)
        expect(c2.id).not_to eq(@vm2.id)
        expect(c2.uid_ems).not_to eq(@vm1.uid_ems)
      end

      it "should handle dups in the raw data" do
        data = raw_data_with_dups(@vm1, @vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(2)
        v1, v2 = vms.sort_by(&:id)

        expect(v1.id).to eq(@vm1.id)
        expect(v1.uid_ems).to eq(@vm1.uid_ems)
        expect(v1.ems_id).not_to be_nil

        expect(v2.id).to eq(@vm2.id)
        expect(v2.uid_ems).to eq(@vm2.uid_ems)
      end
    end

    context "with non-dup on a different EMS in the database" do
      before(:each) do
        @ems2 = FactoryGirl.create(:ems_vmware)
        @uid  = MiqUUID.new_guid
        @vm1  = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems2, :uid_ems => @uid)
        @vm2  = FactoryGirl.build(:vm_with_ref, :ext_management_system => @ems, :uid_ems => @uid)
      end

      it "should handle new dup in the raw_data" do
        data = raw_data_process(@vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(2)
        v1, v2 = vms.sort_by(&:id)

        expect(v1.id).to eq(@vm1.id)
        expect(v1.uid_ems).to eq(@vm1.uid_ems)
        expect(v1.ems_id).to eq(@ems2.id)

        expect(v2.id).not_to eq(@vm1.id)
        expect(v2.uid_ems).to eq(@vm1.uid_ems)
        expect(v2.ems_id).to eq(@ems.id)
      end
    end

    context "with disconnected non-dup in the database" do
      before(:each) do
        @uid  = MiqUUID.new_guid
        @vm1 = FactoryGirl.create(:vm_with_ref, :ext_management_system => nil, :uid_ems => @uid)
        @vm2 = FactoryGirl.build(:vm_with_ref, :ext_management_system => @ems, :uid_ems => @uid)
      end

      it "should handle new dup in the raw_data" do
        data = raw_data_process(@vm2)
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(1)
        v = vms.first

        expect(v.id).to eq(@vm1.id)
        expect(v.uid_ems).to eq(@vm1.uid_ems)
      end
    end

    context "with no dups in the database, but with nil ems_refs (after upgrade)" do
      before(:each) do
        @vm1 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
        @vm2 = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)

        @ems_ref1 = @vm1.ems_ref_obj
        @ems_ref2 = @vm2.ems_ref_obj
        @vm1.ems_ref_obj = @vm2.ems_ref_obj = nil
        @vm1.save
        @vm2.save
      end

      # TODO: DRY up these tests with the others just like them
      it "should handle no dups in the raw data" do
        data = raw_data_without_dups(@vm1, @vm2)
        data[0][:ems_ref_obj] = @ems_ref1
        data[1][:ems_ref_obj] = @ems_ref2
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(2)
        v1, v2 = vms.sort_by(&:id)

        expect(v1.id).to eq(@vm1.id)
        expect(v1.uid_ems).to eq(@vm1.uid_ems)

        expect(v2.id).to eq(@vm2.id)
        expect(v2.uid_ems).to eq(@vm2.uid_ems)
      end

      it "should handle dups in the raw data" do
        data = raw_data_with_dups(@vm1, @vm2)
        data[0][:ems_ref_obj] = @ems_ref1
        data[1][:ems_ref_obj] = @ems_ref2
        EmsRefresh.save_vms_inventory(@ems, data)

        vms = Vm.all
        expect(vms.length).to eq(3)

        disconnected, connected = vms.partition { |v| v.ems_id.nil? }
        expect(disconnected.length).to eq(1)
        expect(connected.length).to eq(2)

        d      = disconnected.first
        c1, c2 = connected.sort_by(&:id)

        expect(d.id).to eq(@vm2.id)
        expect(d.uid_ems).to eq(@vm2.uid_ems)

        expect(c1.id).to eq(@vm1.id)
        expect(c1.uid_ems).to eq(@vm1.uid_ems)

        expect(c2.id).not_to eq(@vm1.id)
        expect(c2.id).not_to eq(@vm2.id)
        expect(c2.uid_ems).to eq(@vm1.uid_ems)
      end
    end
  end

  private

  RAW_DATA_ATTRS = [:name, :ems_ref_obj, :ems_ref, :vendor, :location, :uid_ems, :type]

  def raw_data_process(*args)
    args.collect do |v|
      RAW_DATA_ATTRS.each_with_object({}) { |s, h| h[s] = v.send(s) }
    end
  end

  def raw_data_with_dups(*args)
    data = raw_data_process(*args)
    data[1][:uid_ems] = data[0][:uid_ems]
    data
  end

  def raw_data_without_dups(*args)
    data = raw_data_process(*args)
    data[1][:uid_ems] = MiqUUID.new_guid if data[0][:uid_ems] == data[1][:uid_ems]
    data
  end

  def dump_before(data)
    puts "**VMS BEFORE"
    puts Vm.all.collect { |v| [v.id, v.name, v.uid_ems, v.ems_ref_obj, v.ems_ref, v.ems_id].inspect }.join("\n")
    puts "**DATA"
    puts data.collect(&:inspect).join("\n")
  end

  def dump_after
    puts "**VMS AFTER"
    puts Vm.all.collect { |v| [v.id, v.name, v.uid_ems, v.ems_ref_obj, v.ems_ref, v.ems_id].inspect }.join("\n")
  end
end
