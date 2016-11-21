describe MiqGroup do
  context "set as Super Administrator" do
    before(:each) do
      @miq_group = FactoryGirl.create(:miq_group, :group_type => "system", :role => "super_administrator")
    end

    describe ".remove_tag_from_all_managed_filters" do
      let(:other_miq_group) { FactoryGirl.create(:miq_group) }
      let(:filters) { [["/managed/prov_max_memory/test", "/managed/prov_max_memory/1024"], ["/managed/my_name/test"]] }

      before do
        @miq_group.set_managed_filters(filters)
        other_miq_group.set_managed_filters(filters)
        [@miq_group, other_miq_group].each(&:save)
      end

      it "removes managed filter from all groups" do
        MiqGroup.all.each { |group| expect(group.get_managed_filters).to match_array(filters) }

        MiqGroup.remove_tag_from_all_managed_filters("/managed/my_name/test")

        expected_filters = [["/managed/prov_max_memory/test", "/managed/prov_max_memory/1024"]]
        MiqGroup.all.each { |group| expect(group.get_managed_filters).to match_array(expected_filters) }
      end
    end

    context "#get_filters" do
      it "normal" do
        expected = {:test => "test filter"}
        @miq_group.filters = expected
        expect(@miq_group.get_filters).to eq(expected)
      end

      it "when nil" do
        @miq_group.filters = nil
        expect(@miq_group.get_filters).to eq("managed" => [], "belongsto" => [])
      end

      it "when {}" do
        @miq_group.filters = {}
        expect(@miq_group.get_filters).to eq({})
      end
    end

    context "#has_filters?" do
      it "normal" do
        @miq_group.filters = {"managed" => %w(a)}
        expect(@miq_group).to be_has_filter
      end

      it "when other" do
        @miq_group.filters = {"other" => %(x)}
        expect(@miq_group).not_to be_has_filter
      end

      it "when nil" do
        @miq_group.filters = nil
        expect(@miq_group).not_to be_has_filter
      end

      it "when {}" do
        @miq_group.filters = {}
        expect(@miq_group).not_to be_has_filter
      end
    end

    %w(managed belongsto).each do |type|
      context "#get_#{type}_filters" do
        let(:method) { "get_#{type}_filters" }

        it "normal" do
          expected = {type => "test filter"}
          @miq_group.filters = expected
          expect(@miq_group.public_send(method)).to eq(expected[type])
        end

        it "when nil" do
          @miq_group.filters = nil
          expect(@miq_group.public_send(method)).to eq([])
        end

        it "when []" do
          @miq_group.filters = []
          expect(@miq_group.public_send(method)).to eq([])
        end

        it "missing the #{type} key" do
          expected = {"something" => "test filter"}
          @miq_group.filters = expected
          expect(@miq_group.public_send(method)).to eq([])
        end
      end

      it "#set_#{type}_filters" do
        filters = {type => "test"}
        @miq_group.public_send("set_#{type}_filters", filters[type])
        expect(@miq_group.public_send("get_#{type}_filters")).to eq(filters[type])
        expect(@miq_group.get_filters).to eq(filters)
      end
    end

    it "should return user role name" do
      expect(@miq_group.miq_user_role_name).to eq("EvmRole-super_administrator")
    end

    it "should set group type to 'system' " do
      expect(@miq_group.group_type).to eq("system")
    end

    it "should return user count" do
      # TODO: - add more users to check for proper user count...
      expect(@miq_group.user_count).to eq(0)
    end

    it "should strip group description of leading and trailing spaces" do
      @miq_group.description = "      leading and trailing white spaces     "
      expect(@miq_group.description).to eq("leading and trailing white spaces")
    end
  end

  describe "#get_ldap_groups_by_user_with_ext_auth" do
    before do
      require "dbus"
      sysbus = double('sysbus')
      ifp_service = double('ifp_service')
      ifp_object  = double('ifp_object')
      @ifp_interface = double('ifp_interface')

      allow(DBus).to receive(:system_bus).and_return(sysbus)
      allow(sysbus).to receive(:[]).with("org.freedesktop.sssd.infopipe").and_return(ifp_service)
      allow(ifp_service).to receive(:object).with("/org/freedesktop/sssd/infopipe").and_return(ifp_object)
      allow(ifp_object).to receive(:introspect)
      allow(ifp_object).to receive(:[]).with("org.freedesktop.sssd.infopipe").and_return(@ifp_interface)
    end

    it "should return groups by user name with external authentication" do
      memberships = [%w(foo bar)]

      allow(@ifp_interface).to receive(:GetUserGroups).with('user').and_return(memberships)

      expect(MiqGroup.get_httpd_groups_by_user('user')).to eq(memberships.first)
    end

    it "should remove FQDN from the groups by user name with external authentication" do
      ifp_memberships = [%w(foo@fqdn bar@fqdn)]
      memberships = [%w(foo bar)]

      allow(@ifp_interface).to receive(:GetUserGroups).with('user').and_return(ifp_memberships)

      expect(MiqGroup.get_httpd_groups_by_user('user')).to eq(memberships.first)
    end
  end

  describe "#get_ldap_groups_by_user" do
    before do
      stub_server_configuration(:authentication => {:group_memberships_max_depth => 1})

      miq_ldap = double('miq_ldap',
                        :fqusername      => 'fred',
                        :normalize       => 'fred flintstone',
                        :bind            => true,
                        :get_user_object => 'user object',
                        :get_memberships => %w(foo bar))
      allow(MiqLdap).to receive(:new).and_return(miq_ldap)
    end

    it "should return LDAP groups by user name" do
      expect(MiqGroup.get_ldap_groups_by_user('fred', 'bind_dn', 'password')).to eq(%w(foo bar))
    end

    it "should issue an error message when user name could not be bound to LDAP" do
      allow(MiqLdap.new).to receive_messages(:bind => false)
      # darn, wanted a MiqException::MiqEVMLoginError
      expect do
        MiqGroup.get_ldap_groups_by_user('fred', 'bind_dn', 'password')
      end.to raise_error(RuntimeError, "Bind failed for user bind_dn")
    end

    it "should issue an error message when user name does not exist in LDAP directory" do
      allow(MiqLdap.new).to receive_messages(:get_user_object => nil)

      # darn, wanted a MiqException::MiqEVMLoginError
      expect do
        MiqGroup.get_ldap_groups_by_user('fred', 'bind_dn', 'password')
      end.to raise_error(RuntimeError, "Unable to find user fred in directory")
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

      @hw1 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @hw2 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @hw3 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @hw4 = FactoryGirl.create(:hardware, :cpu_total_cores => @num_cpu, :memory_mb => @ram_size)
      @disk1 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw1.id)
      @disk2 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw2.id)
      @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw3.id)
      @disk3 = FactoryGirl.create(:disk, :device_type => "disk", :size => @disk_size, :hardware_id => @hw4.id)

      @active_vm = FactoryGirl.create(:vm_vmware,
                                      :name         => "Active VM",
                                      :miq_group_id => @miq_group.id,
                                      :ems_id       => @ems.id,
                                      :storage_id   => @storage.id,
                                      :hardware     => @hw1)
      @archived_vm = FactoryGirl.create(:vm_vmware,
                                        :name         => "Archived VM",
                                        :miq_group_id => @miq_group.id,
                                        :hardware     => @hw2)
      @orphaned_vm = FactoryGirl.create(:vm_vmware,
                                        :name         => "Orphaned VM",
                                        :miq_group_id => @miq_group.id,
                                        :storage_id   => @storage.id,
                                        :hardware     => @hw3)
      @retired_vm = FactoryGirl.create(:vm_vmware,
                                       :name         => "Retired VM",
                                       :miq_group_id => @miq_group.id,
                                       :retired      => true,
                                       :hardware     => @hw4)
    end

    it "#active_vms" do
      expect(@miq_group.active_vms).to match_array([@active_vm])
    end

    it "#allocated_memory" do
      expect(@miq_group.allocated_memory).to eq(@ram_size.megabyte)
    end

    it "#allocated_vcpu" do
      expect(@miq_group.allocated_vcpu).to eq(@num_cpu)
    end

    it "#allocated_storage" do
      expect(@miq_group.allocated_storage).to eq(@disk_size)
    end

    it "#provisioned_storage" do
      expect(@miq_group.provisioned_storage).to eq(@ram_size.megabyte + @disk_size)
    end

    %w(allocated_memory allocated_vcpu allocated_storage provisioned_storage).each do |vcol|
      it "should have virtual column #{vcol} " do
        expect(described_class).to have_virtual_column "#{vcol}", :integer
      end
    end

    it "when the virtual column is nil" do
      hw = FactoryGirl.create(:hardware, :cpu_sockets => @num_cpu, :memory_mb => @ram_size)
      FactoryGirl.create(:vm_vmware,
                         :name         => "VM with no disk",
                         :miq_group_id => @miq_group.id,
                         :ems_id       => @ems.id,
                         :storage_id   => @storage.id,
                         :hardware     => hw)
      expect(@miq_group.allocated_storage).to eq(@disk_size)
    end
  end

  describe "#destroy" do
    let(:group) { FactoryGirl.create(:miq_group) }

    it "can succeed" do
      expect { group.destroy }.not_to raise_error
    end

    it "fails if referenced by user#current_group" do
      FactoryGirl.create(:user, :miq_groups => [group])

      expect {
        expect { group.destroy }.to raise_error(RuntimeError, /Still has users assigned/)
      }.to_not change { MiqGroup.count }
    end

    it "fails if referenced by user#miq_groups" do
      group2 = FactoryGirl.create(:miq_group)
      FactoryGirl.create(:user, :miq_groups => [group, group2], :current_group => group2)

      expect {
        expect { group.destroy }.to raise_error(RuntimeError, /Still has users assigned/)
      }.to_not change { MiqGroup.count }
    end

    it "fails if referenced by a tenant#default_miq_group" do
      expect { FactoryGirl.create(:tenant).default_miq_group.reload.destroy }
        .to raise_error(RuntimeError, /A tenant default group can not be deleted/)
    end
  end

  context "#seed" do
    it "adds new groups after initial seed" do
      [Tenant, MiqUserRole, MiqGroup].each(&:seed)

      role_map_path = ApplicationRecord::FIXTURE_DIR.join("role_map.yaml")
      role_map = YAML.load_file(role_map_path)
      role_map = {'EvmRole-test_role' => 'tenant_quota_administrator'}.merge(role_map)
      filter_map_path = ApplicationRecord::FIXTURE_DIR.join("filter_map.yaml")

      allow(YAML).to receive(:load_file).with(role_map_path).and_return(role_map)
      allow(YAML).to receive(:load_file).with(filter_map_path).and_call_original

      expect {
        MiqGroup.seed
      }.to change { MiqGroup.count }
      expect(MiqGroup.last.name).to eql('EvmRole-test_role')
      expect(MiqGroup.last.sequence).to eql(1)
    end

    context "tenant groups" do
      let!(:tenant) { Tenant.seed }
      let!(:group_with_no_entitlement) { tenant.default_miq_group }
      let!(:group_with_existing_entitlement) do
        FactoryGirl.create(:miq_group,
                           :tenant_type,
                           :entitlement => FactoryGirl.create(:entitlement, :miq_user_role => nil))
      end
      let(:default_tenant_role) { MiqUserRole.default_tenant_role }

      before do
        MiqUserRole.seed
        expect(group_with_no_entitlement.entitlement).not_to be_present
        expect(group_with_no_entitlement.miq_user_role).not_to be_present
        expect(group_with_existing_entitlement.entitlement).to be_present
        expect(group_with_existing_entitlement.miq_user_role).not_to be_present
        MiqGroup.seed
        group_with_no_entitlement.reload
        group_with_existing_entitlement.reload
      end

      it "assigns the default_tenant_role to tenant_groups without roles" do
        expect(group_with_no_entitlement.entitlement).to be_present
        expect(group_with_no_entitlement.miq_user_role).to eq(default_tenant_role)
        expect(group_with_existing_entitlement.entitlement).to be_present
        expect(group_with_existing_entitlement.miq_user_role).to eq(default_tenant_role)
      end
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

  context ".sort_by_desc" do
    it "sorts by description" do
      tenant = FactoryGirl.create(:tenant)
      gc = FactoryGirl.create(:miq_group, :description => 'C', :tenant => tenant)
      ga = FactoryGirl.create(:miq_group, :description => 'a', :tenant => tenant)
      gb = FactoryGirl.create(:miq_group, :description => 'B', :tenant => tenant)

      expect(tenant.miq_groups.sort_by_desc).to eq([ga, gb, gc, tenant.default_miq_group])
    end
  end

  describe "#read_only" do
    it "is not read_only for regular groups" do
      expect(FactoryGirl.create(:miq_group)).not_to be_read_only
    end

    it "is read_only for system groups" do
      expect(FactoryGirl.create(:miq_group, :system_type)).to be_read_only
    end

    it "is read_only for tenant groups" do
      expect(FactoryGirl.create(:tenant).default_miq_group).to be_read_only
    end
  end

  describe "#self_service" do
    it "detects role" do
      role = FactoryGirl.create(
        :miq_user_role,
        :role     => "self_service",
        :settings => {:restrictions => {:vms => :user_or_group}}
      )
      group = FactoryGirl.create(:miq_group,
                                 :description   => "MiqGroup-self_service",
                                 :miq_user_role => role
                                )
      expect(group).to be_self_service
    end

    it "detects non-role" do
      group = FactoryGirl.create(:miq_group, :role => "abc")
      expect(group).not_to be_self_service
    end
  end

  describe "#system_group?" do
    it "is not system_group for regular groups" do
      expect(FactoryGirl.create(:miq_group)).not_to be_system_group
    end

    it "is system_group for system groups" do
      expect(FactoryGirl.create(:miq_group, :system_type)).to be_system_group
    end
  end

  describe "#tenant_group" do
    it "is not tenant_group for regular groups" do
      expect(FactoryGirl.create(:miq_group)).not_to be_tenant_group
    end

    it "is tenant_group for tenant groups" do
      expect(FactoryGirl.create(:tenant).default_miq_group).to be_tenant_group
    end
  end

  describe "#tenant=" do
    it "changes for non default groups" do
      tenant = FactoryGirl.create(:tenant)
      g = FactoryGirl.create(:miq_group)
      g.update_attributes(:tenant => tenant)
      expect(g.tenant).to eq(tenant)
    end

    it "fails for default groups" do
      tenant = FactoryGirl.create(:tenant)
      g = FactoryGirl.create(:tenant).default_miq_group
      expect { g.update_attributes!(:tenant => tenant) }
        .to raise_error(ActiveRecord::RecordInvalid, /Tenant cant change the tenant of a default group/)
    end
  end

  describe '.tenant_groups' do
    it "brings back only tenant_groups" do
      tg = FactoryGirl.create(:tenant).default_miq_group
      g  = FactoryGirl.create(:miq_group)

      expect(MiqGroup.tenant_groups).to include(tg)
      expect(MiqGroup.tenant_groups).not_to include(g)
    end
  end

  describe '.non_tenant_groups' do
    it "brings back only non_tenant_groups" do
      tg = FactoryGirl.create(:tenant).default_miq_group
      g  = FactoryGirl.create(:miq_group)

      expect(MiqGroup.non_tenant_groups).not_to include(tg)
      expect(MiqGroup.non_tenant_groups).to include(g)
    end
  end

  describe ".next_sequence" do
    it "creates the first group" do
      MiqGroup.delete_all
      expect(MiqGroup.next_sequence).to eq(1)
    end

    it "detects existing groups" do
      expect(MiqGroup.next_sequence).to be < 999 # sanity check
      FactoryGirl.create(:miq_group, :sequence => 999)
      expect(MiqGroup.next_sequence).to eq(1000)
    end

    it "handles nil sequences" do
      MiqGroup.delete_all
      g = FactoryGirl.create(:miq_group)
      g.update_attribute(:sequence, nil)

      expect(MiqGroup.next_sequence).to eq(1)
    end

    it "auto assigns a sequences" do
      # don't want to get behavior from factory girl
      g1 = MiqGroup.create(:description => "one")
      g2 = MiqGroup.create(:description => "two")

      expect(g1.sequence).to be_truthy
      expect(g2.sequence).to eq(g1.sequence + 1)
    end

    it "builds a sequence based upon select criteria" do
      expect(MiqGroup.next_sequence).to be < 999 # sanity check

      FactoryGirl.create(:miq_group, :description => "want 1", :sequence => 999)
      FactoryGirl.create(:miq_group, :description => "want 2", :sequence => 1000)
      FactoryGirl.create(:miq_group, :description => "dont want", :sequence => 1009)

      expect(MiqGroup.where("description like 'want%'").next_sequence).to eq(1001)
    end
  end
end
