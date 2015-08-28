require "spec_helper"

describe MiqGroup do

  context "set as Super Administrator" do

    before(:each) do
      # create User Role record...
      @miq_user_role = FactoryGirl.create(
                      :miq_user_role,
                      :name       => "EVMGroup-super_administrator",
                      :read_only  => true,
                      :settings   => nil
                      )

      # create Miq Group record...
      @guid = MiqUUID.new_guid
      MiqGroup.stub(:my_guid).and_return(@guid)
      @miq_group = FactoryGirl.create(
                  :miq_group,
                  :guid             => @guid,
                  :description      => "EVMGroup-super_administrator",
                  :group_type       => "system",
                  :miq_user_role    => @miq_user_role
                  )

    end

    context "#get_filters" do
      it "normal" do
        expected = {:test => "test filter"}
        @miq_group.filters = expected
        @miq_group.get_filters.should == expected
      end

      it "when nil" do
        @miq_group.filters = nil
        @miq_group.get_filters.should be_nil
      end

      it "when {}" do
        @miq_group.filters = {}
        @miq_group.get_filters.should == {}
      end
    end

    %w{managed belongsto}.each do |type|
      context "#get_#{type}_filters" do
        let(:method) { "get_#{type}_filters" }

        it "normal" do
          expected = {type => "test filter"}
          @miq_group.filters = expected
          @miq_group.public_send(method).should == expected[type]
        end

        it "when nil" do
          @miq_group.filters = nil
          @miq_group.public_send(method).should == []
        end

        it "when []" do
          @miq_group.filters = []
          @miq_group.public_send(method).should == []
        end

        it "missing the #{type} key" do
          expected = {"something" => "test filter"}
          @miq_group.filters = expected
          @miq_group.public_send(method).should == []
        end
      end

      it "#set_#{type}_filters" do
        filters = {type => "test"}
        @miq_group.public_send("set_#{type}_filters", filters[type])
        @miq_group.public_send("get_#{type}_filters").should == filters[type]
        @miq_group.get_filters.should == filters
      end
    end

    it "should return user role name" do
      @miq_group.miq_user_role_name.should == "EVMGroup-super_administrator"
    end

    it "should set group type to 'system' " do
      @miq_group.group_type.should == "system"
    end

    it "should return user count" do
      #TODO - add more users to check for proper user count...
      @miq_group.user_count.should == 0
    end

    it "should strip group description of leading and trailing spaces" do
      @miq_group.description = "      leading and trailing white spaces     "
      @miq_group.description.should == "leading and trailing white spaces"
    end

    it "should return LDAP groups by user name" do
      auth_config = { :group_memberships_max_depth => 1 }
      stub_server_configuration(:authentication =>  auth_config)

      miq_ldap = double('miq_ldap')
      miq_ldap.stub(:fqusername => 'fred')
      miq_ldap.stub(:normalize => 'fred flintstone')
      miq_ldap.stub(:bind => true)
      miq_ldap.stub(:get_user_object => 'user object')
      memberships = [ 'foo', 'bar' ]
      miq_ldap.stub(:get_memberships => memberships)
      MiqLdap.stub(:new).and_return(miq_ldap)

      MiqGroup.get_ldap_groups_by_user('user', 'bind_dn', 'password').should == memberships
    end

    it "should issue an error message when user name could not be bound to LDAP" do
      auth_config = { :group_memberships_max_depth => 1 }
      stub_server_configuration(:authentication =>  auth_config)

      miq_ldap = double('miq_ldap')
      miq_ldap.stub(:fqusername => 'fred')
      miq_ldap.stub(:normalize => 'fred flintstone')
      miq_ldap.stub(:bind => false)
      miq_ldap.stub(:get_user_object => 'user object')
      memberships = [ 'foo', 'bar' ]
      miq_ldap.stub(:get_memberships => memberships)
      MiqLdap.stub(:new).and_return(miq_ldap)

      lambda {
              MiqGroup.get_ldap_groups_by_user('user', 'bind_dn', 'password')
             }.should
             raise_error( MiqException::MiqEVMLoginError,
                          "Bind failed for user bind_dn"
                        )
    end

    it "should issue an error message when user name does not exist in LDAP directory" do
      auth_config = { :group_memberships_max_depth => 1 }
      stub_server_configuration(:authentication => auth_config)

      miq_ldap = double('miq_ldap')
      miq_ldap.stub(:fqusername => 'fred')
      miq_ldap.stub(:normalize => 'fred flintstone')
      miq_ldap.stub(:bind => true)
      miq_ldap.stub(:get_user_object => nil)
      memberships = [ 'foo', 'bar' ]
      miq_ldap.stub(:get_memberships => memberships)
      MiqLdap.stub(:new).and_return(miq_ldap)

      lambda {
              MiqGroup.get_ldap_groups_by_user('user', 'bind_dn', 'password')
             }.should
             raise_error( MiqException::MiqEVMLoginError,
                          "Unable to find user fred in directory"
                        )
    end
  end

  context "Testing active VM aggregation" do
    before :each do
      @ram_size = 1024
      @disk_size = 1000000
      @num_cpu = 2

      @miq_group = FactoryGirl.create(:miq_group, :description => "test group")
      @ems = FactoryGirl.create(:ems_vmware, :name => "test_vcenter")
      @storage  = FactoryGirl.create(:storage, :name => "test_storage_nfs", :store_type => "NFS")

      @hw1 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @hw2 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @hw3 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @hw4 = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      @disk1 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw1.id)
      @disk2 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw2.id)
      @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw3.id)
      @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw4.id)

      @active_vm = FactoryGirl.create(:vm_vmware,
                                  :name => "Active VM",
                                  :miq_group_id => @miq_group.id,
                                  :ems_id => @ems.id,
                                  :storage_id => @storage.id,
                                  :hardware => @hw1)
      @archived_vm = FactoryGirl.create(:vm_vmware,
                                    :name => "Archived VM",
                                    :miq_group_id => @miq_group.id,
                                    :hardware => @hw2)
      @orphaned_vm = FactoryGirl.create(:vm_vmware,
                                    :name => "Orphaned VM",
                                    :miq_group_id => @miq_group.id,
                                    :storage_id => @storage.id,
                                    :hardware => @hw3)
      @retired_vm = FactoryGirl.create(:vm_vmware,
                                   :name => "Retired VM",
                                   :miq_group_id => @miq_group.id,
                                   :retired => true,
                                   :hardware => @hw4)
    end

    it "#active_vms" do
      @miq_group.active_vms.should match_array([@active_vm])
    end

    it "#allocated_memory" do
      @miq_group.allocated_memory.should == @ram_size.megabyte
    end

    it "#allocated_vcpu" do
      @miq_group.allocated_vcpu.should == @num_cpu
    end

    it "#allocated_storage" do
      @miq_group.allocated_storage.should == @disk_size
    end

    it "#provisioned_storage" do
      @miq_group.provisioned_storage.should == @ram_size.megabyte + @disk_size
    end

    %w(allocated_memory allocated_vcpu allocated_storage provisioned_storage).each do |vcol|
      it "should have virtual column #{vcol} " do
        described_class.should have_virtual_column "#{vcol}", :integer
      end
    end

    it "when the virtual column is nil" do
      hw = FactoryGirl.create(:hardware, :numvcpus => @num_cpu, :memory_cpu => @ram_size)
      FactoryGirl.create(:vm_vmware,
                         :name         => "VM with no disk",
                         :miq_group_id => @miq_group.id,
                         :ems_id       => @ems.id,
                         :storage_id   => @storage.id,
                         :hardware     => hw)
      @miq_group.allocated_storage.should == @disk_size
    end
  end

  context "should not be deleted while a user is still assigned" do
    before do
      @group = FactoryGirl.create(:miq_group, :description => "remove me")
    end

    it "referenced by current_group" do
      FactoryGirl.create(:user, :userid => "test", :miq_groups => [@group])

      expect { @group.destroy }.to raise_error
      MiqGroup.count.should eq 1
    end

    it "referenced by miq_groups" do
      group2 = FactoryGirl.create(:miq_group, :description => "group2")
      FactoryGirl.create(:user, :userid => "test", :miq_groups => [@group, group2], :current_group => group2)

      expect { @group.destroy }.to raise_error
      MiqGroup.count.should eq 2
    end
  end

  context "#seed" do
    let(:root_tenant) { Tenant.root_tenant }

    it "has tenant_owner for new records" do
      [MiqRegion, Tenant, MiqUserRole, MiqGroup].each(&:seed)
      expect(MiqGroup.where(:tenant_owner_id => root_tenant.id).count).to eq(MiqGroup.count)
    end

    it "has tenant_owner for legacy records" do
      [MiqRegion, Tenant, MiqUserRole].each(&:seed)
      new_tenant           = root_tenant.children.create!
      group_with_tenant    = FactoryGirl.create(:miq_group, :tenant_owner => new_tenant)
      group_without_tenant = FactoryGirl.create(:miq_group, :tenant_owner => nil)
      MiqGroup.seed

      expect(group_with_tenant.reload.tenant_owner).to    eq(new_tenant)
      expect(group_without_tenant.reload.tenant_owner).to eq(root_tenant)
    end
  end

  context "#ordered_widget_sets" do
    let(:group) { FactoryGirl.create(:miq_group) }
    it "uses dashboard_order if present" do
      ws1 = FactoryGirl.create(:miq_widget_set, :name => 'A1', :owner => group)
      ws2 = FactoryGirl.create(:miq_widget_set, :name => 'C3', :owner => group)
      ws3 = FactoryGirl.create(:miq_widget_set, :name => 'B2', :owner => group)
      group.update_attributes(:settings => {:dashboard_order => [ws3.id.to_s, ws1.id.to_s]})

      expect(group.ordered_widget_sets).to eq([ws3, ws1])
    end

    it "uses all owned widgets" do
      ws1 = FactoryGirl.create(:miq_widget_set, :name => 'A1', :owner => group)
      ws2 = FactoryGirl.create(:miq_widget_set, :name => 'C3', :owner => group)
      ws3 = FactoryGirl.create(:miq_widget_set, :name => 'B2', :owner => group)
      expect(group.ordered_widget_sets).to eq([ws1, ws3, ws2])
    end
  end
end
