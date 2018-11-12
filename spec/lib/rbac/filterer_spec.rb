describe Rbac::Filterer do
  describe "using expressions as managed filters" do
    it "supports OR conditions across categories" do
      filter = MiqExpression.new(
        "OR" => [
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "managed-location", "value" => "ny"}}
        ]
      )
      group = create_group_with_expression(filter)
      user = FactoryGirl.create(:user, :miq_groups => [group])
      vm1, vm2, _vm3 = FactoryGirl.create_list(:vm_vmware, 3)
      vm1.tag_with("/managed/environment/prod", :ns => "*")
      vm2.tag_with("/managed/location/ny", :ns => "*")

      actual, = Rbac::Filterer.search(:targets => Vm, :user => user)

      expected = [vm1, vm2]
      expect(actual).to match(expected)
    end

    it "supports AND conditions within categories" do
      filter = MiqExpression.new(
        "AND" => [
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "test"}}
        ]
      )
      group = create_group_with_expression(filter)
      user = FactoryGirl.create(:user, :miq_groups => [group])
      vm1, vm2, vm3 = FactoryGirl.create_list(:vm_vmware, 3)
      vm1.tag_with("/managed/environment/prod /managed/environment/test", :ns => "*")
      vm2.tag_with("/managed/environment/prod", :ns => "*")
      vm3.tag_with("/managed/environment/test", :ns => "*")

      actual, = Rbac::Filterer.search(:targets => Vm, :user => user)

      expected = [vm1]
      expect(actual).to match(expected)
    end

    it "doesn't filter by tags on classes that are not taggable" do
      filter = MiqExpression.new(
        "AND" => [
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "prod"}},
          {"CONTAINS" => {"tag" => "managed-environment", "value" => "test"}}
        ]
      )
      group = create_group_with_expression(filter)
      user = FactoryGirl.create(:user, :miq_groups => [group])
      request = FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => user)

      actual, = Rbac::Filterer.search(:targets => MiqProvisionRequest, :user => user)

      expect(request.class.include?(ActsAsTaggable)).to be_falsey
      expected = [request]
      expect(actual).to match(expected)
    end

    def create_group_with_expression(expression)
      role = FactoryGirl.create(:miq_user_role)
      group = FactoryGirl.create(:miq_group, :tenant => Tenant.root_tenant, :miq_user_role => role)
      group.entitlement = Entitlement.new
      group.entitlement.filter_expression = expression
      group.save!
      group
    end
  end

  describe '.combine_filtered_ids' do
    # Algorithm (from Rbac::Filterer.combine_filtered_ids):
    # b_intersection_m        = (belongsto_filtered_ids INTERSECTION managed_filtered_ids)
    # u_union_d_union_b_and_m = user_filtered_ids UNION descendant_filtered_ids UNION belongsto_filtered_ids
    # filter                  = u_union_d_union_b_and_m INTERSECTION tenant_filter_ids

    def combine_filtered_ids(user_filtered_ids, belongsto_filtered_ids, managed_filtered_ids, descendant_filtered_ids, tenant_filter_ids)
      Rbac::Filterer.new.send(:combine_filtered_ids, user_filtered_ids, belongsto_filtered_ids, managed_filtered_ids, descendant_filtered_ids, tenant_filter_ids)
    end

    it 'only user filter(self service user)' do
      expect(combine_filtered_ids([1, 2], nil, nil, nil, nil)).to match_array([1, 2])
    end

    it 'only belongs to filter(Host & Cluster filter)' do
      expect(combine_filtered_ids(nil, [1, 2], nil, nil, nil)).to match_array([1, 2])
    end

    it 'only managed filter(tags)' do
      expect(combine_filtered_ids(nil, nil, [1, 2], nil, nil)).to match_array([1, 2])
    end

    it 'only descendants filter' do
      expect(combine_filtered_ids(nil, nil, nil, [1, 2], nil)).to match_array([1, 2])
    end

    it 'only tenant filter' do
      expect(combine_filtered_ids(nil, nil, nil, nil, [1, 2])).to match_array([1, 2])
    end

    it 'belongs to and tenant filter' do
      expect(combine_filtered_ids(nil, [1, 2], nil, nil, [2, 3])).to match_array([2])
    end

    it 'belongs to and managed filters(Host & Cluster filter and tags)' do
      expect(combine_filtered_ids(nil, [1, 2], [2, 3], nil, nil)).to match_array([2])
    end

    it 'user filter, belongs to and managed filters(self service user, Host & Cluster filter and tags)' do
      expect(combine_filtered_ids([1], [2, 3], [3, 4], nil, nil)).to match_array([1, 3])
    end

    it 'user filter, belongs to, managed filters and descendants filter(self service user, Host & Cluster filter and tags)' do
      expect(combine_filtered_ids([1], [2, 3], [3, 4], [5, 6], nil)).to match_array([1, 3, 5, 6])
    end

    it 'user filter, belongs to managed filters, descendants filter and tenant filter(self service user, Host & Cluster filter and tags)' do
      expect(combine_filtered_ids([1], [2, 3], [3, 4], [5, 6], [1, 6])).to match_array([1, 6])
    end

    it 'belongs to managed filters, descendants filter and tenant filter(self service user, Host & Cluster filter and tags)' do
      expect(combine_filtered_ids(nil, [2, 3], [3, 4], [5, 6], [1, 6])).to match_array([6])
    end
  end

  before { allow(User).to receive_messages(:server_timezone => "UTC") }

  let(:default_tenant)     { Tenant.seed }

  let(:admin_user)         { FactoryGirl.create(:user, :role => "super_administrator") }

  let(:owner_tenant)       { FactoryGirl.create(:tenant) }
  let(:owner_group)        { FactoryGirl.create(:miq_group, :tenant => owner_tenant) }
  let(:owner_user)         { FactoryGirl.create(:user, :miq_groups => [owner_group]) }
  let(:owned_vm)           { FactoryGirl.create(:vm_vmware, :tenant => owner_tenant) }

  let(:other_tenant)       { FactoryGirl.create(:tenant) }
  let(:other_group)        { FactoryGirl.create(:miq_group, :tenant => other_tenant) }
  let(:other_user)         { FactoryGirl.create(:user, :miq_groups => [other_group]) }
  let(:other_vm)           { FactoryGirl.create(:vm_vmware, :tenant => other_tenant) }

  let(:child_tenant)       { FactoryGirl.create(:tenant, :divisible => false, :parent => owner_tenant) }
  let(:child_group)        { FactoryGirl.create(:miq_group, :tenant => child_tenant) }
  let(:child_user)         { FactoryGirl.create(:user, :miq_groups => [child_group]) }
  let(:child_openstack_vm) { FactoryGirl.create(:vm_openstack, :tenant => child_tenant, :miq_group => child_group) }

  describe ".search" do
    context 'for MiqRequests' do
      # MiqRequest for owner group
      let!(:miq_request_user_owner) { FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => owner_user) }
      # User for owner group
      let(:user_a)                        { FactoryGirl.create(:user, :miq_groups => [owner_group]) }

      # MiqRequests for other group
      let!(:miq_request_user_a)     { FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => other_user) }
      let!(:miq_request_user_b)     { FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => user_b) }

      # other_group is from owner_tenant
      let(:other_group)                   { FactoryGirl.create(:miq_group, :tenant => owner_tenant) }
      # User for other group
      let(:user_b)                        { FactoryGirl.create(:user, :miq_groups => [other_group]) }

      context "self service user (User or group owned)" do
        before do
          allow(other_group).to receive(:self_service?).and_return(true)
          allow(owner_group).to receive(:self_service?).and_return(true)
        end

        context 'users are in same tenant as requester' do
          it "displays requests of user's of group owner_group" do
            results = described_class.search(:class => MiqProvisionRequest, :user => user_a).first
            expect(results).to match_array([miq_request_user_owner])
          end

          it "displays requests for users of other_user's group (other_group) so also for user_c" do
            results = described_class.search(:class => MiqProvisionRequest, :user => user_b).first
            expect(results).to match_array([miq_request_user_a, miq_request_user_b])
          end
        end
      end

      context "limited self service user (only user owned)" do
        before do
          allow(other_group).to receive(:limited_self_service?).and_return(true)
          allow(other_group).to receive(:self_service?).and_return(true)
          allow(owner_group).to receive(:limited_self_service?).and_return(true)
          allow(owner_group).to receive(:self_service?).and_return(true)
        end

        context 'users are in same tenant as requester' do
          it "displays requests of user's of group owner_group" do
            results = described_class.search(:class => MiqProvisionRequest, :user => user_a).first
            expect(results).to be_empty
          end

          it "displays requests for users of other_user's group (other_group) so also for user_c" do
            results = described_class.search(:class => MiqProvisionRequest, :user => user_b).first
            expect(results).to match_array([miq_request_user_b])
          end
        end
      end
    end

    context 'with tags' do
      let(:role)         { FactoryGirl.create(:miq_user_role) }
      let(:tagged_group) { FactoryGirl.create(:miq_group, :tenant => Tenant.root_tenant, :miq_user_role => role) }
      let(:user)         { FactoryGirl.create(:user, :miq_groups => [tagged_group]) }

      before do
        tagged_group.entitlement = Entitlement.new
        tagged_group.entitlement.set_belongsto_filters([])
        tagged_group.entitlement.set_managed_filters([["/managed/environment/prod"]])
        tagged_group.save!
      end

      context 'searching for instances of Switches' do
        let!(:switch) { FactoryGirl.create_list(:switch, 2).first }

        before do
          switch.tag_with('/managed/environment/prod', :ns => '*')
        end

        it 'lists only tagged Switches' do
          results = described_class.search(:class => Switch, :user => user).first
          expect(results).to match_array [switch]
        end

        it 'lists only all Switches' do
          results = described_class.search(:class => Switch, :user => admin_user).first
          expect(results).to match_array Switch.all
        end
      end

      context 'searching for instances of ConfigurationScriptSource' do
        let!(:configuration_script_source) { FactoryGirl.create_list(:embedded_ansible_configuration_script_source, 2).first }

        it 'lists only tagged ConfigurationScriptSources' do
          configuration_script_source.tag_with('/managed/environment/prod', :ns => '*')

          results = described_class.search(:class => ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource, :user => user).first
          expect(results).to match_array [configuration_script_source]
        end
      end

      %w(
        automation_manager_authentication ManageIQ::Providers::AutomationManager::Authentication
        embedded_automation_manager_authentication ManageIQ::Providers::EmbeddedAutomationManager::Authentication
      ).slice(2) do |factory, klass|
        context "searching for instances of #{klass}" do
          let!(:automation_manager_authentication) { FactoryGirl.create(factory) }
          automation_manager_authentication.tag_with('/managed/environment/prod', :ns => '*')

          results = described_class.search(:class => automation_manager_authentication.class.name, :user => user).first
          expect(results.first).to eq(automation_manager_authentication)
        end
      end

      it "tag entitled playbook with no tagged authentications" do
        auth     = FactoryGirl.create(:automation_manager_authentication)
        playbook = FactoryGirl.create(:ansible_playbook, :authentications => [auth])
        playbook.tag_with('/managed/environment/prod', :ns => '*')

        results = described_class.search(:class => playbook.class, :user => user).first
        expect(results).to match_array [playbook]

        results = described_class.search(:class => auth.class, :user => user).first
        expect(results).to match_array []
      end

      it "tag entitled ansible authentications without a playbook for it" do
        auth     = FactoryGirl.create(:automation_manager_authentication)
        playbook = FactoryGirl.create(:ansible_playbook, :authentications => [auth])
        auth.tag_with('/managed/environment/prod', :ns => '*')

        results = described_class.search(:class => playbook.class, :user => user).first
        expect(results).to match_array []

        results = described_class.search(:class => auth.class, :user => user).first
        expect(results).to match_array [auth]
      end

      context 'searching for instances of AuthKeyPair' do
        let!(:auth_key_pair_cloud) { FactoryGirl.create_list(:auth_key_pair_cloud, 2).first }

        it 'lists only tagged AuthKeyPairs' do
          auth_key_pair_cloud.tag_with('/managed/environment/prod', :ns => '*')

          results = described_class.search(:class => ManageIQ::Providers::CloudManager::AuthKeyPair, :user => user).first
          expect(results).to match_array [auth_key_pair_cloud]
        end
      end

      context 'searching for instances of HostAggregate' do
        let!(:host_aggregate) { FactoryGirl.create_list(:host_aggregate, 2).first }

        it 'lists only tagged HostAggregates' do
          host_aggregate.tag_with('/managed/environment/prod', :ns => '*')

          results = described_class.search(:class => HostAggregate, :user => user).first
          expect(results).to match_array [host_aggregate]
        end
      end

      context "searching for tenants" do
        before do
          owner_tenant.tag_with('/managed/environment/prod', :ns => '*')
        end

        it 'list tagged tenants' do
          results = described_class.search(:class => Tenant, :user => user).first
          expect(results).to match_array [owner_tenant]
        end
      end
    end

    context 'with virtual custom attributes' do
      let(:virtual_custom_attribute_1) { "virtual_custom_attribute_attribute_1" }
      let(:virtual_custom_attribute_2) { "virtual_custom_attribute_attribute_2" }
      let!(:vm_1)                { FactoryGirl.create(:vm) }
      let!(:vm_2)                { FactoryGirl.create(:vm) }

      let!(:custom_attribute_1) do
        FactoryGirl.create(:custom_attribute, :name => 'attribute_1', :value => vm_1.name, :resource => vm_1)
      end

      let!(:custom_attribute_2) do
        FactoryGirl.create(:custom_attribute, :name => 'attribute_2', :value => 'any_value', :resource => vm_1)
      end

      let(:miq_expression) do
        exp1 = {'EQUAL' => {'field' => 'Vm-name', 'value' => "Vm-#{virtual_custom_attribute_1}"}}
        exp2 = {'EQUAL' => {'field' => "Vm-#{virtual_custom_attribute_2}", "value" => 'any_value'}}

        MiqExpression.new("AND" => [exp1, exp2])
      end

      it 'returns instance of Vm with related condition' do
        User.with_user(admin_user) do
          results = described_class.search(:class => Vm, :filter => miq_expression).first
          expect(results).to match_array [vm_1]
        end
      end
    end

    describe "with find_options_for_tenant filtering (basic) all resources" do
      {
        "ExtManagementSystem"    => :ems_vmware,
        "MiqAeDomain"            => :miq_ae_domain,
        # "MiqRequest"           => :miq_request,  # MiqRequest can't be instantiated, it is an abstract class
        "MiqRequestTask"         => :miq_request_task,
        "Provider"               => :provider,
        "Service"                => :service,
        "ServiceTemplate"        => :service_template,
        "ServiceTemplateCatalog" => :service_template_catalog,
        "Vm"                     => :vm_vmware
      }.each do |klass, factory_name|
        it "with :user finds #{klass}" do
          owned_resource = FactoryGirl.create(factory_name, :tenant => owner_tenant)
          _other_resource = FactoryGirl.create(factory_name, :tenant => other_tenant)
          results = described_class.filtered(klass, :user => owner_user)
          expect(results).to match_array [owned_resource]
        end
      end
    end

    context 'when class does not participate in RBAC' do
      before do
        @vm = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host1, :ext_management_system => @ems)
        ["2010-04-14T20:52:30Z", "2010-04-14T21:51:10Z"].each do |t|
          @vm.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => t)
        end
      end
      let(:miq_ae_domain) { FactoryGirl.create(:miq_ae_domain) }

      it 'returns the same class as input for MiqAeDomain' do
        User.with_user(admin_user) do
          results = described_class.search(:targets => [miq_ae_domain]).first
          expect(results.first).to be_an_instance_of(MiqAeDomain)
          expect(results).to match_array [miq_ae_domain]
        end
      end

      it 'returns the same class as input for parent class that is not STI' do
        User.with_user(admin_user) do
          targets = @vm.metric_rollups

          results = described_class.search(:targets => targets, :user => admin_user)
          objects = results.first
          expect(objects.length).to eq(2)
          expect(objects).to match_array(targets)
        end
      end

      it 'returns the same class as input for subclass that is not STI' do
        User.with_user(admin_user) do
          vm_perf = VmPerformance.find(@vm.metric_rollups.last.id)
          targets = [vm_perf]

          results = described_class.search(:targets => targets, :user => admin_user)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array(targets)
        end
      end
    end

    context "with non-sql filter" do
      subject { described_class.new }

      let(:nonsql_expression) { {"=" => {"field" => "Vm-vendor_display", "value" => "VMware"}} }
      let(:raw_expression)    { nonsql_expression }
      let(:expression)        { MiqExpression.new(raw_expression) }
      let(:search_attributes) { { :class => "Vm", :filter => expression } }
      let(:results)           { subject.search(search_attributes).first }

      before { [owned_vm, other_vm] }

      it "finds the Vms" do
        expect(results.to_a).to match_array [owned_vm, other_vm]
        expect(results.count).to eq 2
      end

      it "does not add references without includes" do
        expect(subject).to receive(:include_references).with(anything, Vm, nil, nil, true).and_call_original
        results
      end

      context "with a partial non-sql filter" do
        let(:sql_expression) { { "IS EMPTY" => { "field" => "Vm.host-name" } } }
        let(:raw_expression) { { "AND" => [nonsql_expression, sql_expression] } }

        it "finds the Vms" do
          expect(results.to_a).to match_array [owned_vm, other_vm]
          expect(results.count).to eq 2
        end

        it "includes references" do
          expect(subject).to receive(:include_references).with(anything, ::Vm, nil, {:host => {}}, false)
                                                         .and_call_original
          expect(subject).to receive(:warn).never
          results
        end
      end

      context "with :include_for_find" do
        let(:include_search) { search_attributes.merge(:include_for_find => {:evm_owner => {}}) }
        let(:results)        { subject.search(include_search).first }

        it "finds the Vms" do
          expect(results.to_a).to match_array [owned_vm, other_vm]
          expect(results.count).to eq 2
        end

        it "does not add references since there isn't a SQL filter" do
          expect(subject).to receive(:include_references).with(anything, Vm, {:evm_owner => {}}, nil, true).and_call_original
          results
        end

        context "with a references based where_clause" do
          let(:search_with_where) { include_search.merge(:where_clause => ['"users"."id" = ?', owner_user.id]) }
          let(:results)           { subject.search(search_with_where).first }

          it "will try to skip references to begin with" do
            expect(subject).to receive(:include_references).with(anything, Vm, {:evm_owner => {}}, nil, true).and_call_original
            expect(subject).to receive(:warn).exactly(4).times
            results
          end

          context "and targets is a NullRelation scope" do
            let(:targets)     { Vm.none }
            let(:null_search) { search_with_where.merge(:targets => targets) }
            let(:results)     { subject.search(null_search).first }

            it "will not try to skip references" do
              expect(subject).to receive(:include_references).with(anything, Vm, {:evm_owner => {}}, nil, false).and_call_original
              expect(subject).to receive(:warn).never
              results
            end
          end
        end
      end
    end

    context "with a miq_expression filter on vms" do
      let(:expression)        { MiqExpression.new("=" => {"field" => "Vm-vendor", "value" => "vmware"}) }
      let(:search_attributes) { { :class => "Vm", :filter => expression } }
      let(:results)           { described_class.search(search_attributes).first }

      before { [owned_vm, other_vm] }

      it "finds the Vms" do
        expect(results.to_a).to match_array [owned_vm, other_vm]
        expect(results.count).to eq 2
      end

      it "does not add references without includes" do
        # empty string here is basically passing `.references(nil)`, and the
        # extra empty hash here is from the MiqExpression (which will result in
        # the same), both of which will no-op to when determining if there are
        # joins in ActiveRecord, and will not create a JoinDependency query
        expect(results.references_values).to match_array ["", "{}"]
      end

      context "with :include_for_find" do
        let(:include_search) { search_attributes.merge(:include_for_find => {:evm_owner => {}}) }
        let(:results)        { described_class.search(include_search).first }

        it "finds the Service" do
          expect(results.to_a).to match_array [owned_vm, other_vm]
          expect(results.count).to eq 2
        end

        it "adds references" do
          expect(results.references_values).to match_array ["{:evm_owner=>{}}", "{}"]
        end
      end
    end

    context "with :extra_cols on a Service" do
      let(:extra_cols)        { [:owned_by_current_user] }
      let(:search_attributes) { { :class => "Service", :extra_cols => extra_cols } }
      let(:results)           { described_class.search(search_attributes).first }

      before { FactoryGirl.create :service, :evm_owner => owner_user }

      it "finds the Service" do
        expect(results.first.attributes["owned_by_current_user"]).to be false
      end

      it "does not add references with no includes" do
        # The single empty string is the result of a nil from both the lack of
        # a MiqExpression filter and the user filter, which is deduped in
        # ActiveRecord's internals and results in a `.references(nil)`
        # effectively
        expect(results.references_values).to match_array [""]
      end

      context "with :include_for_find" do
        let(:include_search) { search_attributes.merge(:include_for_find => {:evm_owner => {}}) }
        let(:results)        { described_class.search(include_search).first }

        it "finds the Service" do
          expect(results.first.attributes["owned_by_current_user"]).to be false
        end

        it "adds references" do
          expect(results.references_values).to match_array ["", "{:evm_owner=>{}}"]
        end
      end
    end

    describe "with find_options_for_tenant filtering" do
      before do
        owned_vm # happy path
        other_vm # sad path
      end

      it "with User.with_user finds Vm" do
        User.with_user(owner_user) do
          results = described_class.search(:class => "Vm").first
          expect(results).to match_array [owned_vm]
        end
      end

      it "with :user finds Vm" do
        results = described_class.search(:class => "Vm", :user => owner_user).first
        expect(results).to match_array [owned_vm]
      end

      it "with :userid finds Vm" do
        results = described_class.search(:class => "Vm", :userid => owner_user.userid).first
        expect(results).to match_array [owned_vm]
      end

      it "with :miq_group, finds Vm" do
        results = described_class.search(:class => "Vm", :miq_group => owner_group).first
        expect(results).to match_array [owned_vm]
      end

      it "with :miq_group_id finds Vm" do
        results = described_class.search(:class => "Vm", :miq_group_id => owner_group.id).first
        expect(results).to match_array [owned_vm]
      end

      it "leaving tenant doesnt find Vm" do
        owner_user.update_attributes(:miq_groups => [other_user.current_group])
        User.with_user(owner_user) do
          results = described_class.search(:class => "Vm").first
          expect(results).to match_array [other_vm]
        end
      end

      describe "with accessible_tenant_ids filtering (strategy = :descendants_id)" do
        it "can't see parent tenant's Vm" do
          results = described_class.search(:class => "Vm", :miq_group => child_group).first
          expect(results).to match_array []
        end

        it "can see descendant tenant's Vms" do
          child_vm = FactoryGirl.create(:vm_vmware, :tenant => child_tenant)

          results = described_class.search(:class => "Vm", :miq_group => owner_group).first
          expect(results).to match_array [owned_vm, child_vm]
        end

        it "can see descendant tenant's Openstack Vm" do
          child_openstack_vm

          results = described_class.search(:class => "ManageIQ::Providers::Openstack::CloudManager::Vm", :miq_group => owner_group).first
          expect(results).to match_array [child_openstack_vm]
        end

        it "can see current tenant's descendants when non-admin user is logged" do
          User.with_user(other_user) do
            results = described_class.search(:class => "Tenant").first
            expect(results).to match_array([other_tenant])
          end
        end

        it "can see current tenant's descendants when admin user is logged" do
          User.with_user(admin_user) do
            results = described_class.search(:class => "Tenant").first
            expect(results).to match_array([default_tenant, owner_tenant, other_tenant])
          end
        end
      end

      context "with accessible_tenant_ids filtering (strategy = :parent_ids)" do
        it "can see parent tenant's EMS" do
          ems = FactoryGirl.create(:ems_vmware, :tenant => owner_tenant)
          results = described_class.search(:class => "ExtManagementSystem", :miq_group => child_group).first
          expect(results).to match_array [ems]
        end

        it "can't see descendant tenant's EMS" do
          _ems = FactoryGirl.create(:ems_vmware, :tenant => child_tenant)
          results = described_class.search(:class => "ExtManagementSystem", :miq_group => owner_group).first
          expect(results).to match_array []
        end
      end

      context "with accessible_tenant_ids filtering (strategy = nil aka tenant only)" do
        it "can see tenant's request task" do
          task = FactoryGirl.create(:miq_request_task, :tenant => owner_tenant)
          results = described_class.search(:class => "MiqRequestTask", :miq_group => owner_group).first
          expect(results).to match_array [task]
        end

        it "can't see parent tenant's request task" do
          _task = FactoryGirl.create(:miq_request_task, :tenant => owner_tenant)
          results = described_class.search(:class => "MiqRequestTask", :miq_group => child_group).first
          expect(results).to match_array []
        end

        it "can't see descendant tenant's request task" do
          _task = FactoryGirl.create(:miq_request_task, :tenant => child_tenant)
          results = described_class.search(:class => "MiqRequestTask", :miq_group => owner_group).first
          expect(results).to match_array []
        end
      end

      context "with accessible_tenant_ids filtering (strategy = :descendants_id) through" do
        it "can see their own request in the same tenant" do
          request = FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => owner_user)
          results = described_class.search(:class => "MiqRequest", :user => owner_user).first
          expect(results).to match_array [request]
        end

        it "a child tenant user in a group with tag filters can see their own request" do
          child_group.entitlement = Entitlement.new
          child_group.entitlement.set_managed_filters([["/managed/environment/prod"], ["/managed/service_level/silver"]])
          child_group.entitlement.set_belongsto_filters([])
          child_group.save!

          request = FactoryGirl.create(:miq_provision_request, :tenant => child_tenant, :requester => child_user)
          results = described_class.search(:class => "MiqRequest", :user => child_user).first
          expect(results).to match_array [request]
        end

        it "can see other's request in the same tenant" do
          group = FactoryGirl.create(:miq_group, :tenant => owner_tenant)
          user  = FactoryGirl.create(:user, :miq_groups => [group])

          request = FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => owner_user)
          results = described_class.search(:class => "MiqRequest", :user => user).first
          expect(results).to match_array [request]
        end

        it "can't see parent tenant's request" do
          FactoryGirl.create(:miq_provision_request, :tenant => owner_tenant, :requester => owner_user)
          results = described_class.search(:class => "MiqRequest", :miq_group => child_group).first
          expect(results).to match_array []
        end

        it "can see descendant tenant's request" do
          request = FactoryGirl.create(:miq_provision_request, :tenant => child_tenant, :requester => child_user)
          results = described_class.search(:class => "MiqRequest", :miq_group => owner_group).first
          expect(results).to match_array [request]
        end
      end

      context "tenant access strategy VMs and Templates" do
        let(:owned_template) { FactoryGirl.create(:template_vmware, :tenant => owner_tenant) }
        let(:child_tenant)   { FactoryGirl.create(:tenant, :divisible => false, :parent => owner_tenant) }
        let(:child_group)    { FactoryGirl.create(:miq_group, :tenant => child_tenant) }

        context 'with Vm as resource of VmPerformance model' do
          let!(:root_tenant_vm)              { FactoryGirl.create(:vm_vmware, :tenant => Tenant.root_tenant) }
          let!(:vm_performance_root_tenant)  { FactoryGirl.create(:vm_performance, :resource => root_tenant_vm) }
          let!(:vm_performance_other_tenant) { FactoryGirl.create(:vm_performance, :resource => other_vm) }

          it 'list only other_user\'s VmPerformances' do
            results = described_class.search(:class => VmPerformance, :user => other_user).first
            expect(results).to match_array [vm_performance_other_tenant]
          end

          it 'list all VmPerformances' do
            results = described_class.search(:class => VmPerformance, :user => admin_user).first
            expect(results).to match_array [vm_performance_other_tenant, vm_performance_root_tenant]
          end

          context 'with tags' do
            let(:role)         { FactoryGirl.create(:miq_user_role) }
            let(:tagged_group) { FactoryGirl.create(:miq_group, :tenant => Tenant.root_tenant, :miq_user_role => role) }
            let(:user)         { FactoryGirl.create(:user, :miq_groups => [tagged_group]) }

            before do
              tagged_group.entitlement = Entitlement.new
              tagged_group.entitlement.set_belongsto_filters([])
              tagged_group.entitlement.set_managed_filters([["/managed/environment/prod"]])
              tagged_group.save!
            end

            it 'lists only VmPerformances with tagged resources without any tenant restriction' do
              root_tenant_vm.tag_with('/managed/environment/prod', :ns => '*')

              results = described_class.search(:class => VmPerformance, :user => user).first
              expect(results).to match_array [vm_performance_root_tenant]
            end

            it 'lists only VmPerformances with tagged resources with any tenant restriction' do
              root_tenant_vm.tag_with('/managed/environment/prod', :ns => '*')
              other_vm.tag_with('/managed/environment/prod', :ns => '*')

              results = described_class.search(:class => VmPerformance, :user => other_user).first
              expect(results).to match_array [vm_performance_other_tenant]

              vm_or_template_records = described_class.search(:class => VmOrTemplate, :user => other_user).first
              expect(results.map(&:resource_id)).to match_array vm_or_template_records.map(&:id)
            end
          end
        end

        context "searching MiqTemplate" do
          it "can't see descendant tenant's templates" do
            owned_template.update_attributes!(:tenant_id => child_tenant.id, :miq_group_id => child_group.id)
            results, = described_class.search(:class => "MiqTemplate", :miq_group_id => owner_group.id)
            expect(results).to match_array []
          end

          it "can see ancestor tenant's templates" do
            owned_template.update_attributes!(:tenant_id => owner_tenant.id, :miq_group_id => owner_tenant.id)
            results, = described_class.search(:class => "MiqTemplate", :miq_group_id => child_group.id)
            expect(results).to match_array [owned_template]
          end
        end

        context "searching VmOrTemplate" do
          let(:child_child_tenant) { FactoryGirl.create(:tenant, :divisible => false, :parent => child_tenant) }
          let(:child_child_group)  { FactoryGirl.create(:miq_group, :tenant => child_child_tenant) }

          it "can't see descendant tenant's templates but can see descendant tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            owned_vm.update_attributes(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            results, = described_class.search(:class => "VmOrTemplate", :miq_group_id => child_group.id)
            expect(results).to match_array [owned_vm]
          end

          it "can see ancestor tenant's templates but can't see ancestor tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => owner_tenant.id, :miq_group_id => owner_group.id)
            results, = described_class.search(:class => "VmOrTemplate", :miq_group_id => child_group.id)
            expect(results).to match_array [owned_template]
          end

          it "can see ancestor tenant's templates and descendant tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => owner_tenant.id, :miq_group_id => owner_group.id)
            owned_vm.update_attributes(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            results, = described_class.search(:class => "VmOrTemplate", :miq_group_id => child_group.id)
            expect(results).to match_array [owned_template, owned_vm]
          end

          it "can't see descendant tenant's templates nor ancestor tenant's VMs" do
            owned_template.update_attributes!(:tenant_id => child_child_tenant.id, :miq_group_id => child_child_group.id)
            owned_vm.update_attributes(:tenant_id => owner_tenant.id, :miq_group_id => owner_group.id)
            results, = described_class.search(:class => "VmOrTemplate", :miq_group_id => child_group.id)
            expect(results).to match_array []
          end
        end

        context "searching CloudTemplate" do
          let(:group) { FactoryGirl.create(:miq_group, :tenant => default_tenant) } # T1
          let(:admin_user) { FactoryGirl.create(:user, :role => "super_administrator") }
          let!(:cloud_template_root) { FactoryGirl.create(:template_cloud, :publicly_available => false) }

          let(:tenant_2) { FactoryGirl.create(:tenant, :parent => default_tenant, :source_type => 'CloudTenant') } # T2
          let(:group_2) { FactoryGirl.create(:miq_group, :tenant => tenant_2) } # T1
          let(:user_2) { FactoryGirl.create(:user, :miq_groups => [group_2]) }

          context "when tenant is not mapped to cloud tenant" do
            it 'returns all cloud templates when user is admin' do
              User.current_user = admin_user
              results = described_class.filtered(TemplateCloud, :user => admin_user)
              expect(results).to match_array(TemplateCloud.all)
            end

            context "when user is restricted user" do
              let(:tenant_3) { FactoryGirl.create(:tenant, :parent => tenant_2) } # T3
              let!(:cloud_template) { FactoryGirl.create(:template_cloud, :tenant => tenant_3, :publicly_available => true) }

              it "returns all public cloud templates" do
                User.current_user = user_2
                results = described_class.filtered(TemplateCloud, :user => user_2)
                expect(results).to match_array([cloud_template, cloud_template_root])
              end

              context "should ignore other tenant's private cloud templates" do
                let!(:cloud_template) { FactoryGirl.create(:template_cloud, :tenant => tenant_3, :publicly_available => false) }
                it "returns public templates" do
                  User.current_user = user_2
                  results = described_class.filtered(TemplateCloud, :user => user_2)
                  expect(results).to match_array([cloud_template_root])
                end
              end
            end
          end

          context "when tenant is mapped to cloud tenant" do
            let(:tenant_2) { FactoryGirl.create(:tenant, :parent => default_tenant, :source_type => 'CloudTenant', :source_id => 1) }

            it "finds tenant's private cloud templates" do
              cloud_template2 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => false)
              User.current_user = user_2
              results = described_class.filtered(TemplateCloud, :user => user_2)
              expect(results).to match_array([cloud_template2])
            end

            it "finds tenant's private and public cloud templates" do
              cloud_template2 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => false)
              cloud_template3 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => true)
              User.current_user = user_2
              results = described_class.filtered(TemplateCloud, :user => user_2)
              expect(results).to match_array([cloud_template2, cloud_template3])
            end

            it "ignores other tenant's private templates" do
              cloud_template2 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => false)
              cloud_template3 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => true)
              FactoryGirl.create(:template_cloud, :tenant => default_tenant, :publicly_available => false)
              User.current_user = user_2
              results = described_class.filtered(TemplateCloud, :user => user_2)
              expect(results).to match_array([cloud_template2, cloud_template3])
            end

            it "finds other tenant's public templates" do
              cloud_template2 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => false)
              cloud_template3 = FactoryGirl.create(:template_cloud, :tenant => tenant_2, :publicly_available => true)
              cloud_template4 = FactoryGirl.create(:template_cloud, :tenant => default_tenant, :publicly_available => true)
              FactoryGirl.create(:template_cloud, :tenant => default_tenant, :publicly_available => false)
              User.current_user = user_2
              results = described_class.filtered(TemplateCloud, :user => user_2)
              expect(results).to match_array([cloud_template2, cloud_template3, cloud_template4])
            end
          end
        end
      end

      context "tenant 0" do
        it "can see requests owned by any tenants" do
          request_task = FactoryGirl.create(:miq_request_task, :tenant => owner_tenant)
          t0_group = FactoryGirl.create(:miq_group, :tenant => default_tenant)
          results = described_class.search(:class => "MiqRequestTask", :miq_group => t0_group).first
          expect(results).to match_array [request_task]
        end
      end
    end

    context "searching for hosts" do
      it "can filter results by vmm_vendor" do
        host = FactoryGirl.create(:host, :vmm_vendor => "vmware")
        expression = MiqExpression.new("=" => {"field" => "Host-vmm_vendor", "value" => "vmware"})

        results = described_class.search(:class => "Host", :filter => expression).first

        expect(results).to include(host)
      end
    end

    context "searching for vms" do
      it "can filter results by vendor" do
        vm = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        expression = MiqExpression.new("=" => {"field" => "Vm-vendor", "value" => "vmware"})

        results = described_class.search(:class => "Vm", :filter => expression).first

        expect(results).to include(vm)
      end
    end

    context "for Metrics::Rollup" do
      before do
        vm = FactoryGirl.create(:vm_vmware)
        FactoryGirl.create(
          :metric_rollup_vm_daily,
          :resource_id => vm.id,
          :timestamp   => "2010-04-14T00:00:00Z"
        )

        # Typical includes for rendering daily metrics charts
        @include = {
          :max_derived_cpu_available       => {},
          :max_derived_cpu_reserved        => {},
          :min_cpu_usagemhz_rate_average   => {},
          :max_cpu_usagemhz_rate_average   => {},
          :min_cpu_usage_rate_average      => {},
          :max_cpu_usage_rate_average      => {},
          :v_pct_cpu_ready_delta_summation => {},
          :v_pct_cpu_wait_delta_summation  => {},
          :v_pct_cpu_used_delta_summation  => {},
          :max_derived_memory_available    => {},
          :max_derived_memory_reserved     => {},
          :min_derived_memory_used         => {},
          :max_derived_memory_used         => {},
          :min_disk_usage_rate_average     => {},
          :max_disk_usage_rate_average     => {},
          :min_net_usage_rate_average      => {},
          :max_net_usage_rate_average      => {},
          :v_derived_storage_used          => {},
          :resource                        => {}
        }
      end

      # NOTE:  Think long and hard before you consider removing this test.
      # Many-a-hours wasted here determining this bug that resulted in
      # re-adding this test again.
      it "should not raise an error when a polymorphic reflection is included" do
        result = nil
        expect do
          result = described_class.search :class            => "MetricRollup",
                                          :include_for_find => @include
        end.not_to raise_error
        expect(result.first.length).to eq(1)
      end
    end
  end

  context "common setup" do
    let(:group) { FactoryGirl.create(:miq_group, :tenant => default_tenant) }
    let(:user)  { FactoryGirl.create(:user, :miq_groups => [group]) }

    before do
      @tags = {
        2 => "/managed/environment/prod",
        3 => "/managed/environment/dev",
        4 => "/managed/service_level/gold",
        5 => "/managed/service_level/silver"
      }
    end

    def get_rbac_results_for_and_expect_objects(klass, expected_objects)
      User.current_user = user

      results = described_class.search(:targets => klass).first
      expect(results).to match_array(expected_objects)
    end

    context 'with Middleware models' do
      context 'with tags' do
        before do
          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([])
          group.entitlement.set_managed_filters([["/managed/environment/prod"]])
          group.save!
        end

        let(:count_of_created_instances) { 2 }

        %w(
          MiddlewareDatasource
          MiddlewareDeployment
          MiddlewareDomain
          MiddlewareMessaging
          MiddlewareServer
          MiddlewareServerGroup
        ).each do |middleware_model|
          it "returns tagged instance of #{middleware_model}" do
            middleware_instances = FactoryGirl.create_list(middleware_model.tableize.singularize.to_sym,
                                                           count_of_created_instances)
            middleware_instances[0].tag_with('/managed/environment/prod', :ns => '*')
            middleware_model_class = middleware_model.constantize
            expect(middleware_model_class.count).to eq(count_of_created_instances)
            get_rbac_results_for_and_expect_objects(middleware_model_class, [middleware_instances[0]])
          end
        end
      end
    end

    context "with User and Group" do
      context 'with tags' do
        let!(:tagged_group) { FactoryGirl.create(:miq_group, :tenant => default_tenant) }
        let!(:user)         { FactoryGirl.create(:user, :miq_groups => [tagged_group]) }
        let!(:other_user)   { FactoryGirl.create(:user, :miq_groups => [group]) }

        before do
          tagged_group.entitlement = Entitlement.new
          tagged_group.entitlement.set_belongsto_filters([])
          tagged_group.entitlement.set_managed_filters([["/managed/environment/prod"]])
          tagged_group.save!

          tagged_group.tag_with('/managed/environment/prod', :ns => '*')
          user.tag_with('/managed/environment/prod', :ns => '*')
        end

        it 'returns tagged users' do
          expect(User.count).to eq(2)
          get_rbac_results_for_and_expect_objects(User, [user])
        end

        it 'returns tagged groups' do
          expect(MiqGroup.count).to eq(3)
          get_rbac_results_for_and_expect_objects(MiqGroup, [tagged_group])
        end

        let(:tenant_administrator_user_role) do
          FactoryGirl.create(:miq_user_role, :name => MiqUserRole::DEFAULT_TENANT_ROLE_NAME)
        end

        it 'returns tagged groups when user\'s role has disallowed other roles' do
          tagged_group.miq_user_role = tenant_administrator_user_role
          tagged_group.save!

          expect(MiqGroup.count).to eq(3)
          get_rbac_results_for_and_expect_objects(MiqGroup, [tagged_group])
        end
      end

      it "returns users from current user's groups" do
        other_user.miq_groups << group
        get_rbac_results_for_and_expect_objects(User, [user, other_user])
      end

      it "returns user's groups" do
        _expected_groups = [group, other_group] # this will create more groups than 2
        get_rbac_results_for_and_expect_objects(MiqGroup, user.miq_groups)
      end

      context "with self-service user" do
        before do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
        end

        it "returns only the current user" do
          get_rbac_results_for_and_expect_objects(User, [user])
        end

        it "returns only the current group" do
          get_rbac_results_for_and_expect_objects(MiqGroup, [user.current_group])
        end
      end

      context 'with EvmRole-tenant_administrator' do
        let(:rbac_tenant) do
          FactoryGirl.create(:miq_product_feature, :identifier => MiqProductFeature::TENANT_ADMIN_FEATURE)
        end

        let(:tenant_administrator_user_role) do
          FactoryGirl.create(:miq_user_role, :name => MiqUserRole::DEFAULT_TENANT_ROLE_NAME, :miq_product_features => [rbac_tenant])
        end

        let!(:super_administrator_user_role) do
          FactoryGirl.create(:miq_user_role, :role => "super_administrator")
        end

        let(:group) do
          FactoryGirl.create(:miq_group, :tenant => default_tenant, :miq_user_role => tenant_administrator_user_role)
        end

        let!(:user_role) do
          FactoryGirl.create(:miq_user_role, :role => "user")
        end

        let!(:other_group) do
          FactoryGirl.create(:miq_group, :tenant => default_tenant, :miq_user_role => user_role)
        end

        let!(:user) { FactoryGirl.create(:user, :miq_groups => [group]) }

        it 'can see all roles except for EvmRole-super_administrator' do
          expect(MiqUserRole.count).to eq(3)
          get_rbac_results_for_and_expect_objects(MiqUserRole.select(:id, :name), [tenant_administrator_user_role, user_role])
        end

        it 'can see all groups except for group with role EvmRole-super_administrator' do
          expect(MiqUserRole.count).to eq(3)
          default_group_for_tenant = user.current_tenant.miq_groups.where(:group_type => "tenant").first
          super_admin_group
          get_rbac_results_for_and_expect_objects(MiqGroup.select(:id, :description), [group, other_group, default_group_for_tenant])
        end

        it 'can see all groups in the current tenant only' do
          another_tenant = FactoryGirl.create(:tenant)
          another_tenant_group = FactoryGirl.create(:miq_group, :tenant => another_tenant)
          group.tenant = another_tenant

          default_group_for_tenant = user.current_tenant.miq_groups.where(:group_type => "tenant").first
          get_rbac_results_for_and_expect_objects(MiqGroup, [another_tenant_group, default_group_for_tenant])
        end

        let(:super_admin_group) do
          FactoryGirl.create(:miq_group, :tenant => default_tenant, :miq_user_role => super_administrator_user_role)
        end

        let!(:super_admin_user) { FactoryGirl.create(:user, :miq_groups => [super_admin_group]) }

        it 'can see all users except for user with group with role EvmRole-super_administrator' do
          expect(User.count).to eq(2)
          get_rbac_results_for_and_expect_objects(User, [user])
        end
      end
    end

    context "with Hosts" do
      let(:hosts) { [@host1, @host2] }
      before do
        @host1 = FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local")
        @host2 = FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local")
      end

      context "having Metric data" do
        before do
          @timestamps = [
            ["2010-04-14T20:52:30Z", 100.0],
            ["2010-04-14T21:51:10Z", 1.0],
            ["2010-04-14T21:51:30Z", 2.0],
            ["2010-04-14T21:51:50Z", 4.0],
            ["2010-04-14T21:52:10Z", 8.0],
            ["2010-04-14T21:52:30Z", 15.0],
            ["2010-04-14T22:52:30Z", 100.0],
          ]
          @timestamps.each do |t, v|
            [@host1, @host2].each do |h|
              h.metric_rollups << FactoryGirl.create(:metric_rollup_host_hr,
                                                     :timestamp                  => t,
                                                     :cpu_usage_rate_average     => v,
                                                     :cpu_ready_delta_summation  => v * 1000, # Multiply by a factor of 1000 to make it more realistic and enable testing virtual col v_pct_cpu_ready_delta_summation
                                                     :sys_uptime_absolute_latest => v
                                                    )
            end
          end
        end

        context "with only managed filters" do
          before do
            group.entitlement = Entitlement.new
            group.entitlement.set_managed_filters([["/managed/environment/prod"], ["/managed/service_level/silver"]])
            group.entitlement.set_belongsto_filters([])
            group.save!

            @tags = ["/managed/environment/prod"]
            @host2.tag_with(@tags.join(' '), :ns => '*')
            @tags << "/managed/service_level/silver"
          end

          it ".search finds the right HostPerformance rows" do
            @host1.tag_with(@tags.join(' '), :ns => '*')
            results, attrs = described_class.search(:class => "HostPerformance", :user => user)
            expect(attrs[:user_filters]).to eq(group.get_filters)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end

          it ".search filters out the wrong HostPerformance rows with :match_via_descendants option" do
            @vm = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host2)
            @vm.tag_with(@tags.join(' '), :ns => '*')

            results, attrs = described_class.search(:targets => HostPerformance, :class => "HostPerformance", :user => user, :match_via_descendants => Vm)
            expect(attrs[:user_filters]).to eq(group.get_filters)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host2) }
          end

          it ".search filters out the wrong HostPerformance rows" do
            @host1.tag_with(@tags.join(' '), :ns => '*')
            results, attrs = described_class.search(:targets => HostPerformance.all, :class => "HostPerformance", :user => user)
            expect(attrs[:user_filters]).to eq(group.get_filters)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end
        end

        context "with only belongsto filters" do
          before do
            group.entitlement = Entitlement.new
            group.entitlement.set_belongsto_filters(["/belongsto/ExtManagementSystem|ems1"])
            group.entitlement.set_managed_filters([])
            group.save!

            ems1 = FactoryGirl.create(:ems_vmware, :name => 'ems1')
            @host1.update_attributes(:ext_management_system => ems1)
            @host2.update_attributes(:ext_management_system => ems1)

            root = FactoryGirl.create(:ems_folder, :name => "Datacenters")
            root.parent = ems1
            dc = FactoryGirl.create(:ems_folder, :name => "Datacenter1")
            dc.parent = root
            hfolder   = FactoryGirl.create(:ems_folder, :name => "Hosts")
            hfolder.parent = dc
            @host1.parent = hfolder
          end

          it ".search finds the right HostPerformance rows" do
            results, attrs = described_class.search(:class => "HostPerformance", :user => user)
            expect(attrs[:user_filters]).to eq(group.get_filters)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end

          it ".search filters out the wrong HostPerformance rows" do
            results, attrs = described_class.search(:targets => HostPerformance.all, :class => "HostPerformance", :user => user)
            expect(attrs[:user_filters]).to eq(group.get_filters)
            expect(attrs[:auth_count]).to eq(@timestamps.length)
            expect(results.length).to eq(@timestamps.length)
            results.each { |vp| expect(vp.resource).to eq(@host1) }
          end
        end
      end

      context "with VMs and Templates" do
        before do
          @ems = FactoryGirl.create(:ems_vmware, :name => 'ems1')
          @host1.update_attributes(:ext_management_system => @ems)
          @host2.update_attributes(:ext_management_system => @ems)

          root            = FactoryGirl.create(:ems_folder, :name => "Datacenters")
          root.parent     = @ems
          dc              = FactoryGirl.create(:datacenter, :name => "Datacenter1")
          dc.parent       = root
          hfolder         = FactoryGirl.create(:ems_folder, :name => "host")
          hfolder.parent  = dc
          @vfolder        = FactoryGirl.create(:ems_folder, :name => "vm")
          @vfolder.parent = dc
          @host1.parent   = hfolder
          @vm_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}/EmsFolder|#{root.name}/EmsFolder|#{dc.name}/EmsFolder|#{@vfolder.name}"

          @vm       = FactoryGirl.create(:vm_vmware,       :name => "VM1",       :host => @host1, :ext_management_system => @ems)
          @template = FactoryGirl.create(:template_vmware, :name => "Template1", :host => @host1, :ext_management_system => @ems)
        end

        it "honors ems_id conditions" do
          results = described_class.search(:class => "ManageIQ::Providers::Vmware::InfraManager::Template", :conditions => ["ems_id IS NULL"])
          objects = results.first
          expect(objects).to eq([])

          @template.update_attributes(:ext_management_system => nil)
          results = described_class.search(:class => "ManageIQ::Providers::Vmware::InfraManager::Template", :conditions => ["ems_id IS NULL"])
          objects = results.first
          expect(objects).to eq([@template])
        end

        context "search on EMSes" do
          before do
            @ems2 = FactoryGirl.create(:ems_vmware, :name => 'ems2')
          end

          it "preserves order of targets" do
            @ems3 = FactoryGirl.create(:ems_vmware, :name => 'ems3')
            @ems4 = FactoryGirl.create(:ems_vmware, :name => 'ems4')

            targets = [@ems2, @ems4, @ems3, @ems]

            results = described_class.search(:targets => targets, :user => user)
            objects = results.first
            expect(objects.length).to eq(4)
            expect(objects).to eq(targets)
          end

          it "returns the correct class for different classes of targets" do
            @ems3 = FactoryGirl.create(:ems_vmware, :name => 'ems3')
            @ems4 = FactoryGirl.create(:ems_microsoft, :name => 'ems4')

            targets = [@ems2, @ems4, @ems3, @ems]

            results = described_class.search(:targets => targets, :user => user)
            objects = results.first
            expect(objects.length).to eq(4)
            expect(objects).to match_array(targets)
          end

          it "finds both EMSes without belongsto filters" do
            results = described_class.search(:class => "ExtManagementSystem", :user => user)
            objects = results.first
            expect(objects.length).to eq(2)
          end

          it "finds one EMS with belongsto filters" do
            group.entitlement = Entitlement.new
            group.entitlement.set_belongsto_filters([@vm_folder_path])
            group.entitlement.set_managed_filters([])
            group.save!
            results = described_class.search(:class => "ExtManagementSystem", :user => user)
            objects = results.first
            expect(objects).to eq([@ems])
          end
        end

        it "search on VMs and Templates should return no objects if self-service user" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          User.with_user(user) do
            results = described_class.search(:class => "VmOrTemplate")
            objects = results.first
            expect(objects.length).to eq(0)
          end
        end

        it "search on VMs and Templates should return both objects" do
          results = described_class.search(:class => "VmOrTemplate")
          objects = results.first
          expect(objects.length).to eq(2)
          expect(objects).to match_array([@vm, @template])

          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@vm_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!
          results = described_class.search(:class => "VmOrTemplate", :user => user)
          objects = results.first
          expect(objects.length).to eq(0)

          [@vm, @template].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
            v.save
          end

          results = described_class.search(:class => "VmOrTemplate", :user => user)
          objects = results.first
          expect(objects.length).to eq(2)
          expect(objects).to match_array([@vm, @template])
        end

        it "search on VMs should return a single object" do
          results = described_class.search(:class => "Vm")
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@vm])

          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@vm_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!

          results = described_class.search(:class => "Vm", :user => user)
          objects = results.first
          expect(objects.length).to eq(0)

          [@vm, @template].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
            v.save
          end

          results = described_class.search(:class => "Vm", :user => user)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@vm])
        end

        it "search on Templates should return a single object" do
          results = described_class.search(:class => "MiqTemplate")
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@template])

          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@vm_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!

          results = described_class.search(:class => "MiqTemplate", :user => user)
          objects = results.first
          expect(objects.length).to eq(0)

          [@vm, @template].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @vfolder }
            v.save
          end

          results = described_class.search(:class => "MiqTemplate", :user => user)
          objects = results.first
          expect(objects.length).to eq(1)
          expect(objects).to match_array([@template])
        end
      end

      context "when applying a filter to the provider" do
        let(:ems_cloud) { FactoryGirl.create(:ems_cloud) }

        let!(:vm_1) do
          FactoryGirl.create(:vm, :ext_management_system => ems_cloud)
        end

        let!(:vm_2) do
          FactoryGirl.create(:vm, :ext_management_system => ems_cloud)
        end

        it "returns all host's VMs and templates when host filter is set up" do
          group.entitlement = Entitlement.new
          group.entitlement.set_managed_filters([])
          group.entitlement.set_belongsto_filters(["/belongsto/ExtManagementSystem|#{ems_cloud.name}"])
          group.save!

          expect(described_class.search(:class => Vm, :user => user).first).to match_array([vm_1, vm_2])
        end
      end

      context "when applying a filter to the host and it's cluster (FB17114)" do
        before do
          @ems = FactoryGirl.create(:ems_vmware, :name => 'ems')
          @ems_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}"
          @root = FactoryGirl.create(:ems_folder, :name => "Datacenters")
          @root.parent = @ems
          @mtc = FactoryGirl.create(:datacenter, :name => "MTC")
          @mtc.parent = @root
          @mtc_folder_path = "/belongsto/ExtManagementSystem|#{@ems.name}/EmsFolder|#{@root.name}/EmsFolder|#{@mtc.name}"

          @hfolder         = FactoryGirl.create(:ems_folder, :name => "host")
          @hfolder.parent  = @mtc

          @cluster = FactoryGirl.create(:ems_cluster, :name => "MTC Development")
          @cluster.parent = @hfolder
          @cluster_folder_path = "#{@mtc_folder_path}/EmsFolder|#{@hfolder.name}/EmsCluster|#{@cluster.name}"

          @rp = FactoryGirl.create(:resource_pool, :name => "Default for MTC Development")
          @rp.parent = @cluster

          @host_1 = FactoryGirl.create(:host, :name => "Host_1", :ems_cluster => @cluster, :ext_management_system => @ems)
          @host_2 = FactoryGirl.create(:host, :name => "Host_2", :ext_management_system => @ems)

          @vm1 = FactoryGirl.create(:vm_vmware, :name => "VM1", :host => @host_1, :ext_management_system => @ems)
          @vm2 = FactoryGirl.create(:vm_vmware, :name => "VM2", :host => @host_2, :ext_management_system => @ems)

          @template1 = FactoryGirl.create(:template_vmware, :name => "Template1", :host => @host_1, :ext_management_system => @ems)
          @template2 = FactoryGirl.create(:template_vmware, :name => "Template2", :host => @host_2, :ext_management_system => @ems)
        end

        it "returns all host's VMs and templates when host filter is set up" do
          @host_1.parent = @hfolder # add host to folder's hierarchy
          mtc_folder_path_with_host = "#{@mtc_folder_path}/EmsFolder|host/Host|#{@host_1.name}"
          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([mtc_folder_path_with_host])
          group.entitlement.set_managed_filters([])
          group.save!

          ["ManageIQ::Providers::Vmware::InfraManager::Vm", "Vm"].each do |klass|
            results2 = described_class.search(:class => klass, :user => user).first
            expect(results2.length).to eq(1)
          end

          results2 = described_class.search(:class => "VmOrTemplate", :user => user).first
          expect(results2.length).to eq(2)

          ["ManageIQ::Providers::Vmware::InfraManager::Template", "MiqTemplate"].each do |klass|
            results2 = described_class.search(:class => klass, :user => user).first
            expect(results2.length).to eq(1)
          end
        end

        it "get all the descendants without belongsto filter" do
          results, attrs = described_class.search(:class => "Host", :user => user)
          expect(results.length).to eq(4)
          expect(attrs[:auth_count]).to eq(4)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => []})

          results2 = described_class.search(:class => "Vm", :user => user).first
          expect(results2.length).to eq(2)

          results3 = described_class.search(:class => "VmOrTemplate", :user => user).first
          expect(results3.length).to eq(4)
        end

        it "get all the vm or templates with belongsto filter" do
          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@cluster_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!
          results, attrs = described_class.search(:class => "VmOrTemplate", :user => user)
          expect(results.length).to eq(0)
          expect(attrs[:auth_count]).to eq(0)

          [@vm1, @template1].each do |v|
            v.with_relationship_type("ems_metadata") { v.parent = @rp }
            v.save
          end

          results2, attrs = described_class.search(:class => "VmOrTemplate", :user => user)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@cluster_folder_path]})
          expect(attrs[:auth_count]).to eq(2)
          expect(results2.length).to eq(2)
        end

        it "get all the hosts with belongsto filter" do
          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@cluster_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!
          results, attrs = described_class.search(:class => "Host", :user => user)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@cluster_folder_path]})
          expect(attrs[:auth_count]).to eq(1)
          expect(results.length).to eq(1)

          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@mtc_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!
          results2, attrs = described_class.search(:class => "Host", :user => user)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@mtc_folder_path]})
          expect(attrs[:auth_count]).to eq(1)
          expect(results2.length).to eq(1)

          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@ems_folder_path])
          group.entitlement.set_managed_filters([])
          group.save!
          results3, attrs = described_class.search(:class => "Host", :user => user)
          expect(attrs[:user_filters]).to eq({"managed" => [], "belongsto" => [@ems_folder_path]})
          expect(attrs[:auth_count]).to eq(1)
          expect(results3.length).to eq(1)
        end

        it 'searches Hosts with tag and host & cluster filters' do
          group.entitlement = Entitlement.new
          group.entitlement.set_belongsto_filters([@cluster_folder_path])
          group.entitlement.set_managed_filters([['/managed/environment/prod']])
          group.save!

          @host_1.tag_with('/managed/environment/prod', :ns => '*')

          results, attrs = described_class.search(:class => "Host", :user => user)

          expect(attrs[:user_filters]).to eq("managed"   => [['/managed/environment/prod']], "belongsto" => [@cluster_folder_path])
          expect(attrs[:auth_count]).to eq(1)
          expect(results.length).to eq(1)
        end
      end
    end

    context "with services" do
      before do
        @service1 = FactoryGirl.create(:service)
        @service2 = FactoryGirl.create(:service)
        @service3 = FactoryGirl.create(:service, :evm_owner => user)
        @service4 = FactoryGirl.create(:service, :miq_group => group)
        @service5 = FactoryGirl.create(:service, :evm_owner => user, :miq_group => group)
      end

      context ".search" do
        it "self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)

          results = described_class.search(:class => "Service", :miq_group => user.current_group).first
          expect(results.to_a).to match_array([@service4, @service5])
        end

        context "with self-service user" do
          before do
            allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = described_class.search(:class => "Service").first
              expect(results.to_a).to match_array([@service3, @service4, @service5])
            end
          end
        end

        it "limited self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          allow_any_instance_of(MiqGroup).to receive_messages(:limited_self_service? => true)

          results = described_class.search(:class => "Service", :miq_group => user.current_group).first
          expect(results.to_a).to match_array([@service4, @service5])
        end

        context "with limited self-service user" do
          before do
            allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
            allow_any_instance_of(MiqGroup).to receive_messages(:limited_self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = described_class.search(:class => "Service").first
              expect(results.to_a).to match_array([@service3, @service5])
            end
          end
        end

        it "works when targets are a list of ids" do
          results = described_class.search(:targets => Service.all.collect(&:id), :class => "Service").first
          expect(results.length).to eq(5)
          expect(results.first).to be_kind_of(Service)
        end

        it "works when targets are empty" do
          results = described_class.search(:class => "Service").first
          expect(results.length).to eq(5)
        end
      end
    end

    context 'with ansible ConfigurationScripts' do
      describe ".search" do
        let!(:ansible_configuration_script)          { FactoryGirl.create(:ansible_configuration_script) }
        let!(:ansible_configuration_script_with_tag) { FactoryGirl.create(:ansible_configuration_script) }
        let!(:ansible_playbook)                      { FactoryGirl.create(:ansible_playbook) }
        let!(:ansible_playbook_with_tag)             { FactoryGirl.create(:ansible_playbook) }

        it 'works when targets are empty' do
          User.with_user(user) do
            results = described_class.search(:class => 'ConfigurationScript').first
            expect(results).to match_array([ansible_configuration_script, ansible_configuration_script_with_tag])

            results = described_class.search(:class => 'ConfigurationScriptPayload').first
            expect(results).to match_array([ansible_playbook, ansible_playbook_with_tag])
          end
        end

        context 'with tagged ConfigurationScripts' do
          before do
            group.entitlement = Entitlement.new
            group.entitlement.set_managed_filters([['/managed/environment/prod']])
            group.entitlement.set_belongsto_filters([])
            group.save!

            ansible_configuration_script_with_tag.tag_with('/managed/environment/prod', :ns => '*')
            ansible_playbook_with_tag.tag_with('/managed/environment/prod', :ns => '*')
          end

          it 'lists only tagged ConfigurationScripts' do
            User.with_user(user) do
              results = described_class.search(:class => 'ConfigurationScript').first
              expect(results.length).to eq(1)
              expect(results.first).to eq(ansible_configuration_script_with_tag)
            end
          end

          it 'lists only tagged ConfigurationScriptPayload' do
            User.with_user(user) do
              results = described_class.search(:class => 'ConfigurationScriptPayload').first
              expect(results).to match_array([ansible_playbook_with_tag])
            end
          end
        end
      end
    end

    context "with cloud network and network manager" do
      let!(:network_manager)   { FactoryGirl.create(:ems_openstack).network_manager }
      let!(:network_manager_1) { FactoryGirl.create(:ems_openstack).network_manager }

      context "with belongs_to_filter" do
        before do
          group.entitlement = Entitlement.new
          group.entitlement.set_managed_filters([])
          group.entitlement.set_belongsto_filters(["/belongsto/ExtManagementSystem|#{network_manager.name}"])
          group.save!
        end

        (described_class::NETWORK_MODELS_FOR_BELONGSTO_FILTER + [ManageIQ::Providers::NetworkManager]).each do |network_model|
          describe ".search" do
            let!(:network_object) do
              return network_manager if network_model == ManageIQ::Providers::NetworkManager
              FactoryGirl.create(network_model.underscore, :ext_management_system => network_manager)
            end

            let!(:network_object_with_different_network_manager) do
              return network_manager_1 if network_model == ManageIQ::Providers::NetworkManager
              FactoryGirl.create(network_model.underscore,  :ext_management_system => network_manager_1)
            end

            context "when records match belogns to filter" do
              it "lists records of #{network_model} manager according to belongsto filter" do
                User.with_user(user) do
                  results = described_class.search(:class => network_model).first
                  expect(results).to match_array([network_object])
                  expect(results.first.ext_management_system).to eq(network_manager)
                end
              end
            end

            context "when records don't match belogns to filter" do
              before do
                group.entitlement = Entitlement.new
                group.entitlement.set_managed_filters([])
                group.entitlement.set_belongsto_filters(["/belongsto/ExtManagementSystem|XXXX"])
                group.save!
              end

              it "lists no records of #{network_model}" do
                User.with_user(user) do
                  results = described_class.search(:class => network_model).first
                  expect(results).to be_empty
                end
              end
            end
          end
        end
      end

      context "network manager with/without tagging" do
        let!(:cloud_network)     { FactoryGirl.create(:cloud_network, :ext_management_system => network_manager) }
        let!(:cloud_network_1)   { FactoryGirl.create(:cloud_network, :ext_management_system => network_manager_1) }

        context "network manager is tagged" do
          before do
            group.entitlement = Entitlement.new
            group.entitlement.set_managed_filters([["/managed/environment/prod"]])
            group.entitlement.set_belongsto_filters([])
            group.save!

            network_manager.tag_with("/managed/environment/prod", :ns => "*")
          end

          it "doesn't list cloud networks" do
            User.with_user(user) do
              results = described_class.search(:class => CloudNetwork).first
              expect(results).to be_empty
            end
          end

          it "lists only tagged network manager" do
            User.with_user(user) do
              results = described_class.search(:class => ManageIQ::Providers::NetworkManager).first
              expect(results).to match_array([network_manager])
            end
          end
        end

        context "network manager not is tagged" do
          before do
            group.entitlement = Entitlement.new
            group.entitlement.set_managed_filters([])
            group.entitlement.set_belongsto_filters([])
            group.save!
          end

          it "lists all cloud networks" do
            User.with_user(user) do
              results = described_class.search(:class => CloudNetwork).first
              expect(results).to match_array(CloudNetwork.all)
              expect(results.first.ext_management_system).to eq(network_manager)
            end
          end

          it "lists all network managers" do
            User.with_user(user) do
              results = described_class.search(:class => ManageIQ::Providers::NetworkManager).first
              expect(results).to match_array(ManageIQ::Providers::NetworkManager.all)
            end
          end
        end
      end
    end

    context 'with network models' do
      NETWORK_MODELS = %w(
        CloudNetwork
        CloudSubnet
        FloatingIp
        LoadBalancer
        NetworkPort
        NetworkRouter
        SecurityGroup
      ).freeze

      NETWORK_MODELS.each do |network_model|
        describe ".search" do
          let!(:network_object)          { FactoryGirl.create(network_model.underscore) }
          let!(:network_object_with_tag) { FactoryGirl.create(network_model.underscore) }
          let(:network_object_ids)       { [network_object.id, network_object_with_tag.id] }

          it 'works when targets are empty' do
            User.with_user(user) do
              results = described_class.search(:class => network_model, :targets => network_object_ids).first
              expect(results).to match_array([network_object, network_object_with_tag])
            end
          end

          context "with tagged #{network_model}" do
            before do
              group.entitlement = Entitlement.new
              group.entitlement.set_managed_filters([['/managed/environment/prod']])
              group.entitlement.set_belongsto_filters([])
              group.save!

              network_object_with_tag.tag_with('/managed/environment/prod', :ns => '*')
            end

            it "lists only tagged #{network_model}" do
              User.with_user(user) do
                results = described_class.search(:class => network_model).first
                expect(results.length).to eq(1)
                expect(results.first).to eq(network_object_with_tag)
              end
            end
          end
        end
      end
    end

    context "with tagged VMs" do
      let(:ems) { FactoryGirl.create(:ext_management_system) }

      before do
        [
          FactoryGirl.create(:host, :name => "Host1", :hostname => "host1.local"),
          FactoryGirl.create(:host, :name => "Host2", :hostname => "host2.local"),
          FactoryGirl.create(:host, :name => "Host3", :hostname => "host3.local"),
          FactoryGirl.create(:host, :name => "Host4", :hostname => "host4.local")
        ].each_with_index do |host, i|
          grp = i + 1
          guest_os = %w(_none_ windows ubuntu windows ubuntu)[grp]
          vm = FactoryGirl.build(:vm_vmware, :name => "Test Group #{grp} VM #{i}")
          vm.hardware = FactoryGirl.build(:hardware, :cpu_sockets => (grp * 2), :memory_mb => (grp * 1.megabytes), :guest_os => guest_os)
          vm.host = host
          vm.evm_owner_id = user.id  if i.even?
          vm.miq_group_id = group.id if i.odd?
          vm.ext_management_system = ems if i.even?
          vm.save
          vm.tag_with(@tags.values.join(" "), :ns => "*") if i > 0
        end

        Vm.scope :group_scope,    ->(group_num) { Vm.where("name LIKE ?", "Test Group #{group_num}%") }
        Vm.scope :is_on,          ->            { Vm.where(:power_state => "on") }
      end

      context ".search" do
        it "self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)

          results = described_class.search(:class => "Vm", :miq_group => user.current_group).first
          expect(results.length).to eq(2)
        end

        context "with self-service user" do
          before do
            allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = described_class.search(:class => "Vm").first
              expect(results.length).to eq(4)
            end
          end

          it "works when passing a named_scope" do
            User.with_user(user) do
              results = described_class.search(:class => "Vm", :named_scope => [[:group_scope, 1]]).first
              expect(results.length).to eq(1)
            end
          end
        end

        it "limited self-service group" do
          allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
          allow_any_instance_of(MiqGroup).to receive_messages(:limited_self_service? => true)

          results = described_class.search(:class => "Vm", :miq_group => user.current_group).first
          expect(results.length).to eq(2)
        end

        context "with limited self-service user" do
          before do
            allow_any_instance_of(MiqGroup).to receive_messages(:self_service? => true)
            allow_any_instance_of(MiqGroup).to receive_messages(:limited_self_service? => true)
          end

          it "works when targets are empty" do
            User.with_user(user) do
              results = described_class.search(:class => "Vm").first
              expect(results.length).to eq(2)
            end
          end

          it "works when passing a named_scope" do
            User.with_user(user) do
              results = described_class.search(:class => "Vm", :named_scope => [[:group_scope, 1]]).first
              expect(results.length).to eq(1)

              results = described_class.search(:class => "Vm", :named_scope => [[:group_scope, 2]]).first
              expect(results.length).to eq(0)
            end
          end
        end

        it "works when targets are a list of ids" do
          results = described_class.search(:targets => Vm.all.collect(&:id), :class => "Vm").first
          expect(results.length).to eq(4)
          expect(results.first).to be_kind_of(Vm)
        end

        it "works when targets are empty" do
          results = described_class.search(:class => "Vm").first
          expect(results.length).to eq(4)
        end

        it "works when targets is a class" do
          results = described_class.search(:targets => Vm).first
          expect(results.length).to eq(4)
        end

        it "works when passing a named_scope" do
          results = described_class.search(:class => "Vm", :named_scope => :is_on).first
          expect(results.length).to eq(4)
        end

        it "works when passing a named_scope with parameterized scope" do
          results = described_class.search(:class => "Vm", :named_scope => [[:group_scope, 4]]).first
          expect(results.length).to eq(1)
        end

        it "works when passing a named_scope with multiple scopes" do
          results = described_class.search(:class => "Vm", :named_scope => [:is_on, :active]).first
          expect(results.length).to eq(2)
        end

        it "works when passing a named_scope with multiple mixed scopes" do
          results = described_class.search(:class => "Vm", :named_scope => [[:group_scope, 3], :active]).first
          expect(results.length).to eq(1)
        end

        it "works when targets are a named scope" do
          results = described_class.search(:targets => Vm.group_scope(4)).first
          expect(results.length).to eq(1)
        end

        it "works when the filter is not fully supported in SQL (FB11080)" do
          filter = '--- !ruby/object:MiqExpression
          exp:
            or:
            - STARTS WITH:
                value: Test Group 1
                field: Vm-name
            - "=":
                value: Host2
                field: Vm-host_name
          '
          results = described_class.search(:class => "Vm", :filter => YAML.load(filter)).first
          expect(results.length).to eq(2)
        end
      end

      context "with only managed filters (FB9153, FB11442)" do
        before do
          group.entitlement = Entitlement.new
          group.entitlement.set_managed_filters([["/managed/environment/prod"], ["/managed/service_level/silver"]])
          group.save!
        end

        context ".search" do
          it "does not raise any errors when user filters are passed and search expression contains columns in a sub-table" do
            exp = YAML.load("--- !ruby/object:MiqExpression
            exp:
              and:
              - IS NOT EMPTY:
                  field: Vm.host-name
              - IS NOT EMPTY:
                  field: Vm-name
            ")
            expect { described_class.search(:class => "Vm", :filter => exp, :user => user, :order => "vms.name desc") }.not_to raise_error
          end

          it "works when limit, offset and user filters are passed and search expression contains columns in a sub-table" do
            exp = YAML.load("--- !ruby/object:MiqExpression
            exp:
              and:
              - IS NOT EMPTY:
                  field: Vm.host-name
              - IS NOT EMPTY:
                  field: Vm-name
            ")
            results, attrs = described_class.search(:class => "Vm", :filter => exp, :user => user, :limit => 2, :offset => 2, :order => "vms.name desc")
            expect(results.length).to eq(1)
            expect(results.first.name).to eq("Test Group 2 VM 1")
            expect(attrs[:auth_count]).to eq(3)
          end

          it "works when class does not participate in RBAC and user filters are passed" do
            2.times do |i|
              FactoryGirl.create(:ems_event, :timestamp => Time.now.utc, :message => "Event #{i}")
            end

            exp = YAML.load '--- !ruby/object:MiqExpression
            exp:
              IS:
                field: EmsEvent-timestamp
                value: Today
            '

            results, attrs = described_class.search(:class => "EmsEvent", :filter => exp, :user => user)

            expect(results.length).to eq(2)
            expect(attrs[:auth_count]).to eq(2)
            expect(attrs[:user_filters]["managed"]).to eq(group.get_managed_filters)
          end
        end
      end
    end

    context "with group's VMs" do
      let(:group_user) { FactoryGirl.create(:user, :miq_groups => [group2, group]) }
      let(:group2) { FactoryGirl.create(:miq_group, :role => 'support') }

      before do
        4.times do |i|
          FactoryGirl.create(:vm_vmware,
                             :name             => "Test VM #{i}",
                             :connection_state => i < 2 ? 'connected' : 'disconnected',
                             :miq_group        => i.even? ? group : group2)
        end
      end

      it "when filtering on a real column" do
        filter = YAML.load '--- !ruby/object:MiqExpression
        context_type:
        exp:
          CONTAINS:
            value: connected
            field: MiqGroup.vms-connection_state
        '

        User.with_user(group_user) do
          results, attrs = described_class.search(:class => "MiqGroup", :filter => filter, :miq_group => group)
          expect(results.length).to eq(2)
          expect(attrs[:auth_count]).to eq(2)
        end
      end

      it "when filtering on a virtual column (FB15509)" do
        filter = YAML.load '--- !ruby/object:MiqExpression
        context_type:
        exp:
          CONTAINS:
            value: false
            field: MiqGroup.vms-disconnected
        '
        User.with_user(group_user) do
          results, attrs = described_class.search(:class => "MiqGroup", :filter => filter, :miq_group => group)
          expect(results.length).to eq(2)
          expect(attrs[:auth_count]).to eq(2)
        end
      end
    end

    context "database configuration" do
      it "expect all database setting values returned" do
        results = described_class.search(:class               => "VmdbDatabaseSetting",
                              :userid              => "admin",
                              :parent              => nil,
                              :parent_method       => nil,
                              :targets_hash        => true,
                              :association         => nil,
                              :filter              => nil,
                              :sub_filter          => nil,
                              :where_clause        => nil,
                              :named_scope         => nil,
                              :display_filter_hash => nil,
                              :conditions          => nil,
                              :include_for_find    => {:description => {}, :minimum_value => {}, :maximum_value => {}}
                             ).first

        expect(results.length).to eq(VmdbDatabaseSetting.all.length)
      end
    end
  end

  describe ".filtered" do
    let(:matched_vms) { FactoryGirl.create_list(:vm_vmware, 2, :location => "good") }
    let(:other_vms)   { FactoryGirl.create_list(:vm_vmware, 1, :location => "other") }
    let(:all_vms)     { matched_vms + other_vms }

    it "skips rbac on empty empty arrays" do
      all_vms
      expect(described_class.filtered([], :class => Vm)).to eq([])
    end

    # fix once Rbac filtered is fixed
    it "skips rbac on nil targets" do
      all_vms
      expect(described_class.filtered(nil, :class => Vm)).to match_array(all_vms)
    end

    it "supports class target" do
      all_vms
      expect(described_class.filtered(Vm)).to match_array(all_vms)
    end

    it "supports scope all target" do
      all_vms
      expect(described_class.filtered(Vm.all)).to match_array(all_vms)
    end

    it "supports scope all target" do
      all_vms
      expect(described_class.filtered(Vm.where(:location => "good"))).to match_array(matched_vms)
    end

    it "support aaarm object" do
      expect(LiveMetric).to receive(:find).with(:all, :include => {:a => {}}).and_return([:good])
      expect(described_class.filtered(LiveMetric, :include_for_find => {:a => {}}).to_a).to match_array([:good])
    end

    # it returns objects too
    # TODO: cap number of queries here
    it "runs rbac on array target" do
      all_vms
      expect(described_class.filtered(all_vms, :class => Vm)).to match_array(all_vms)
    end

    it "supports limit on scopes" do
      all_vms
      expect(described_class.filtered(Vm.all.limit(2)).size).to eq(2)
      expect(described_class.filtered(Vm.all.limit(2), :limit => 3).size).to eq(3)
    end

    it "supports limits in ruby with limits on scopes" do
      filter = MiqExpression.new("=" => {"field" => "Vm-location", "value" => "b"})
      # force this filter to be evaluated in ruby
      expect(filter).to receive(:sql_supports_atom?).and_return(false)

      FactoryGirl.create_list(:vm_vmware, 3, :location => "a")
      FactoryGirl.create_list(:vm_vmware, 3, :location => "b")
      # ordering by location, so the bad records come first
      # if we limit in sql, then only bad results will come back - and final result size will be 0
      # if we limit in ruby, then all 6 records will come back, we'll filter to 3 and then limit to 2.
      result = described_class.filtered(Vm.limit(2).order(:location), :filter => filter)
      expect(result.size).to eq(2)
    end

    it "supports order on scopes" do
      FactoryGirl.create(:vm_vmware, :location => "a")
      FactoryGirl.create(:vm_vmware, :location => "b")
      FactoryGirl.create(:vm_vmware, :location => "a")
      expect(described_class.filtered(Vm.all.order(:location)).map(&:location)).to eq(%w(a a b))
    end
  end

  describe ".filtered_object" do
    it "with :user keeps vm" do
      result = described_class.filtered_object(owned_vm, :user => owner_user)
      expect(result).to eq(owned_vm)
    end

    it "with :user filters out vm" do
      result = described_class.filtered_object(other_vm, :user => owner_user)
      expect(result).to be_nil
    end
  end

  describe "#include_references (private)" do
    subject { described_class.new }

    let(:skip)             { false }
    let(:klass)            { VmOrTemplate }
    let(:scope)            { klass.all }
    let(:include_for_find) { { :miq_server => {} } }
    let(:exp_includes)     { { :host => {} } }

    it "adds include_for_find .references to the scope" do
      method_args      = [scope, klass, include_for_find, nil, skip]
      resulting_scope  = subject.send(:include_references, *method_args)

      expect(resulting_scope.references_values).to eq(["{:miq_server=>{}}", ""])
    end

    it "adds exp_includes .references to the scope" do
      method_args      = [scope, klass, nil, exp_includes, skip]
      resulting_scope  = subject.send(:include_references, *method_args)

      expect(resulting_scope.references_values).to eq(["", "{:host=>{}}"])
    end

    it "adds include_for_find and exp_includes .references to the scope" do
      method_args      = [scope, klass, include_for_find, exp_includes, skip]
      resulting_scope  = subject.send(:include_references, *method_args)

      expect(resulting_scope.references_values).to eq(["{:miq_server=>{}}", "{:host=>{}}"])
    end

    context "if the include is polymorphic" do
      let(:klass)            { MetricRollup }
      let(:include_for_find) { { :resource => {} } }

      it "does not add .references to the scope" do
        method_args      = [scope, klass, include_for_find, nil, skip]
        resulting_scope  = subject.send(:include_references, *method_args)

        expect(resulting_scope.references_values).to eq([])
      end
    end

    context "when skip is passed as true" do
      let(:skip) { true }

      it "does not add .references to the scope" do
        method_args      = [scope, klass, include_for_find, exp_includes, skip]
        resulting_scope  = subject.send(:include_references, *method_args)

        expect(resulting_scope.references_values).to eq([])
      end

      context "when the scope is invalid without .references" do
        let(:scope)           { klass.where("hosts.name = 'foo'") }
        let(:method_args)     { [scope, klass, include_for_find, exp_includes, skip] }
        let(:resulting_scope) { subject.send(:include_references, *method_args) }

        let(:explain_error_match) do
          Regexp.new(Regexp.escape(<<~PG_ERR.chomp))
            PG::UndefinedTable: ERROR:  missing FROM-clause entry for table "hosts"
            LINE 1: EXPLAIN SELECT "vms".* FROM "vms" WHERE (hosts.name = 'foo')
                                                             ^
            : EXPLAIN SELECT "vms".* FROM "vms" WHERE (hosts.name = 'foo')
          PG_ERR
        end

        it "adds .references to the scope" do
          allow(subject).to receive(:warn)
          expect(resulting_scope.references_values).to eq(["{:miq_server=>{}}", "{:host=>{}}"])
        end

        it "warns that there was an issue in test mode" do
          # This next couple of lines is just used to check that some of the
          # backtrace that we are dumping into the logs is what we expect will
          # for sure be there, and not try to match the entire trace.
          #
          # Does a bit of line addition to avoid this being too brittle and
          # breaking easily, but expect it to break if you update
          # Rbac::Filterer#include_references
          method_file, method_line = subject.method(:include_references).source_location
          explain_stacktrace_includes = [
            "#{method_file}:#{method_line + 10}:in `block in include_references'",
            Thread.current.backtrace[1].gsub(/:\d*:/) { |sub| ":#{sub.tr(":", "").to_i + 7}:" }
          ]

          expect(subject).to receive(:warn).with("There was an issue with the Rbac filter without references!").ordered
          expect(subject).to receive(:warn).with("Consider trying to fix this edge case in Rbac::Filterer!  Error Below:").ordered
          expect(subject).to receive(:warn).with(explain_error_match).ordered
          expect(subject).to receive(:warn).with(array_including(explain_stacktrace_includes)).ordered
          resulting_scope
        end

        it "warns that there was an issue in development mode" do
          expect(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("developement"))

          # See above
          method_file, method_line = subject.method(:include_references).source_location
          explain_stacktrace_includes = [
            "#{method_file}:#{method_line + 10}:in `block in include_references'",
            Thread.current.backtrace[1].gsub(/:\d*:/) { |sub| ":#{sub.tr(":", "").to_i + 7}:" }
          ]

          expect(subject).to receive(:warn).with("There was an issue with the Rbac filter without references!").ordered
          expect(subject).to receive(:warn).with("Consider trying to fix this edge case in Rbac::Filterer!  Error Below:").ordered
          expect(subject).to receive(:warn).with(explain_error_match).ordered
          expect(subject).to receive(:warn).with(array_including(explain_stacktrace_includes)).ordered
          resulting_scope
        end

        it "does not warn that there was an issue in production mode" do
          expect(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

          expect(subject).to receive(:warn).never
          resulting_scope
        end
      end
    end
  end

  it ".apply_rbac_directly?" do
    expect(described_class.new.send(:apply_rbac_directly?, Vm)).to be_truthy
    expect(described_class.new.send(:apply_rbac_directly?, Rbac)).not_to be
  end

  it ".apply_rbac_through_association?" do
    expect(described_class.new.send(:apply_rbac_through_association?, HostMetric)).to be_truthy
    expect(described_class.new.send(:apply_rbac_through_association?, Vm)).not_to be
  end

  describe "find_targets_with_direct_rbac" do
    let(:host_match) { FactoryGirl.create(:host, :hostname => 'good') }
    let(:host_other) { FactoryGirl.create(:host, :hostname => 'bad') }
    let(:vms_match) { FactoryGirl.create_list(:vm_vmware, 2, :host => host_match) }
    let(:vm_host2) { FactoryGirl.create_list(:vm_vmware, 1, :host => host_other) }
    let(:all_vms) { vms_match + vm_host2 }

    it "works with no filters" do
      all_vms
      result = described_class.filtered(Vm)
      expect(result).to match_array(all_vms)
    end

    it "applies find_options[:conditions, :include]" do
      all_vms
      result = described_class.filtered(Vm, :conditions => {"hosts.hostname" => "good"}, :include_for_find => {:host => {}})
      expect(result).to match_array(vms_match)
    end
  end

  context ".lookup_user_group" do
    let(:filter) { described_class.new }
    let(:user1) { FactoryGirl.create(:user_with_group) }
    let(:group_list) { FactoryGirl.create_list(:miq_group, 2) }
    let(:user2) { FactoryGirl.create(:user, :miq_groups => group_list) }

    context "user_group" do
      it "uses user.current_group" do
        _, group = filter.send(:lookup_user_group, user1, nil, nil, nil)
        expect(group).to eq(user1.current_group)
      end

      it "skips lookup if current_group_id passed" do
        # ensuring same_group is a different object from user1.current_group
        same_group = MiqGroup.find_by(:id => user1.current_group.id)
        expect do
          _, group = filter.send(:lookup_user_group, user1, nil, same_group, nil)
          expect(group).to eq(same_group)
        end.to match_query_limit_of(0)
        expect do
          _, group = filter.send(:lookup_user_group, user1, nil, nil, user1.current_group.id)
          expect(group).to eq(same_group)
        end.to match_query_limit_of(0)
        expect do
          _, group = filter.send(:lookup_user_group, user1, nil, nil, user1.current_group.id.to_s)
          expect(group).to eq(same_group)
        end.to match_query_limit_of(0)
      end

      it "skips lookup when group passed in" do
        # ensure user is looked up outside group block
        user2.miq_groups.to_a
        expect do
          _, group = filter.send(:lookup_user_group, user2, nil, nil, group_list.first.id.to_s)
          expect(group).to eq(group_list.first)
        end.to match_query_limit_of(0)
        expect do
          _, group = filter.send(:lookup_user_group, user2, nil, nil, group_list.last.id)
          expect(group).to eq(group_list.last)
        end.to match_query_limit_of(0)
        expect do
          _, group = filter.send(:lookup_user_group, user2, nil, group_list.first, nil)
          expect(group).to eq(group_list.first)
        end.to match_query_limit_of(0)
      end

      it "uses group passed" do
        _, group = filter.send(:lookup_user_group, user2, nil, group_list.first, nil)
        expect(group).to eq(group_list.first)

        _, group = filter.send(:lookup_user_group, user2, nil, group_list.last, nil)
        expect(group).to eq(group_list.last)
      end

      it "fallsback to current_group if not member of group" do
        user1_group = user1.current_group
        _, group = filter.send(:lookup_user_group, user1, nil, FactoryGirl.create(:miq_group), nil)
        expect(group).to eq(user1_group)
      end

      it "uses group passed in when not member of group when super admin" do
        admin = FactoryGirl.create(:user_admin)
        random_group = FactoryGirl.create(:miq_group)
        _, group = filter.send(:lookup_user_group, admin, nil, random_group, nil)
        expect(group).to eq(random_group)
      end

      it "uses group_id passed in when not member of group when super admin" do
        admin = FactoryGirl.create(:user_admin)
        random_group = FactoryGirl.create(:miq_group)
        _, group = filter.send(:lookup_user_group, admin, nil, nil, random_group.id)
        expect(group).to eq(random_group)
      end

      it "does not update user.current_group if user is super admin" do
        admin = FactoryGirl.create(:user_admin)
        admin_group = admin.current_group
        random_group = FactoryGirl.create(:miq_group)
        filter.send(:lookup_user_group, admin, nil, nil, random_group.id)
        expect(admin.current_group).to eq(admin_group)
      end
    end

    context "user" do
      it "uses user passed in" do
        user, = filter.send(:lookup_user_group, user1, nil, nil, nil)
        expect(user).to eq(user1)
      end

      it "uses string user passed in" do
        user, = filter.send(:lookup_user_group, nil, user1.userid, nil, nil)
        expect(user).to eq(user1)
      end
    end
  end

  describe "cloud_tenant based search" do
    let(:ems_openstack)         { FactoryGirl.create(:ems_cloud) }
    let(:project1_tenant)       { FactoryGirl.create(:tenant, :source_type => 'CloudTenant') }
    let(:project1_cloud_tenant) { FactoryGirl.create(:cloud_tenant, :source_tenant => project1_tenant, :ext_management_system => ems_openstack) }
    let(:project1_group)        { FactoryGirl.create(:miq_group, :tenant => project1_tenant) }
    let(:project1_user)         { FactoryGirl.create(:user, :miq_groups => [project1_group]) }
    let(:project1_volume)       { FactoryGirl.create(:cloud_volume, :ext_management_system => ems_openstack, :cloud_tenant => project1_cloud_tenant) }
    let(:project1_flavor)       { FactoryGirl.create(:flavor, :ext_management_system => ems_openstack) }
    let(:project1_c_t_flavor)   { FactoryGirl.create(:cloud_tenant_flavor, :cloud_tenant => project1_cloud_tenant, :flavor => project1_flavor) }
    let(:project2_tenant)       { FactoryGirl.create(:tenant, :source_type => 'CloudTenant') }
    let(:project2_cloud_tenant) { FactoryGirl.create(:cloud_tenant, :source_tenant => project2_tenant, :ext_management_system => ems_openstack) }
    let(:project2_group)        { FactoryGirl.create(:miq_group, :tenant => project2_tenant) }
    let(:project2_user)         { FactoryGirl.create(:user, :miq_groups => [project2_group]) }
    let(:project2_volume)       { FactoryGirl.create(:cloud_volume, :ext_management_system => ems_openstack, :cloud_tenant => project2_cloud_tenant) }
    let(:project2_flavor)       { FactoryGirl.create(:flavor, :ext_management_system => ems_openstack) }
    let(:project2_c_t_flavor)   { FactoryGirl.create(:cloud_tenant_flavor, :cloud_tenant => project2_cloud_tenant, :flavor => project2_flavor) }
    let(:ems_other)             { FactoryGirl.create(:ems_cloud, :name => 'ems_other', :tenant_mapping_enabled => false) }
    let(:volume_other)          { FactoryGirl.create(:cloud_volume, :ext_management_system => ems_other) }
    let(:tenant_other)          { FactoryGirl.create(:tenant, :source_type => 'CloudTenant') }
    let(:cloud_tenant_other)    { FactoryGirl.create(:cloud_tenant, :source_tenant => tenant_other, :ext_management_system => ems_other) }
    let(:flavor_other)          { FactoryGirl.create(:flavor, :ext_management_system => ems_other) }
    let(:c_t_flavor_other)      { FactoryGirl.create(:cloud_tenant_flavor, :cloud_tenant => cloud_tenant_other, :flavor => flavor_other) }
    let!(:all_objects)          { [project1_volume, project2_volume, volume_other, cloud_tenant_other, project1_c_t_flavor, project2_c_t_flavor, c_t_flavor_other] }

    it "lists its own project's objects and other objects where tenant_mapping is not enabled" do
      ems_openstack.tenant_mapping_enabled = true
      ems_openstack.save!
      results = described_class.search(:class => CloudVolume, :user => project1_user).first
      expect(results).to match_array [project1_volume, volume_other]

      results = described_class.search(:class => CloudVolume, :user => project2_user).first
      expect(results).to match_array [project2_volume, volume_other]

      results = described_class.search(:class => CloudVolume, :user => other_user).first
      expect(results).to match_array [volume_other]

      results = described_class.search(:class => CloudTenant, :user => project1_user).first
      expect(results).to match_array [project1_cloud_tenant, cloud_tenant_other]

      results = described_class.search(:class => CloudTenant, :user => project2_user).first
      expect(results).to match_array [project2_cloud_tenant, cloud_tenant_other]

      results = described_class.search(:class => CloudTenant, :user => other_user).first
      expect(results).to match_array [cloud_tenant_other]

      results = described_class.search(:class => Flavor, :user => project1_user).first
      expect(results).to match_array [project1_flavor, flavor_other]

      results = described_class.search(:class => Flavor, :user => project2_user).first
      expect(results).to match_array [project2_flavor, flavor_other]

      results = described_class.search(:class => Flavor, :user => other_user).first
      expect(results).to match_array [flavor_other]
    end

    it "all objects are visible to all users when tenant_mapping is not enabled" do
      ems_openstack.tenant_mapping_enabled = false
      ems_openstack.save!
      results = described_class.search(:class => CloudVolume, :user => project1_user).first
      expect(results).to match_array [project1_volume, project2_volume, volume_other]

      results = described_class.search(:class => CloudVolume, :user => project2_user).first
      expect(results).to match_array [project1_volume, project2_volume, volume_other]

      results = described_class.search(:class => CloudVolume, :user => owner_user).first
      expect(results).to match_array [project1_volume, project2_volume, volume_other]

      results = described_class.search(:class => CloudTenant, :user => project1_user).first
      expect(results).to match_array [project1_cloud_tenant, project2_cloud_tenant, cloud_tenant_other]

      results = described_class.search(:class => CloudTenant, :user => project2_user).first
      expect(results).to match_array [project1_cloud_tenant, project2_cloud_tenant, cloud_tenant_other]

      results = described_class.search(:class => CloudTenant, :user => other_user).first
      expect(results).to match_array [project1_cloud_tenant, project2_cloud_tenant, cloud_tenant_other]

      results = described_class.search(:class => Flavor, :user => project1_user).first
      expect(results).to match_array [project1_flavor, project2_flavor, flavor_other]

      results = described_class.search(:class => Flavor, :user => project2_user).first
      expect(results).to match_array [project1_flavor, project2_flavor, flavor_other]

      results = described_class.search(:class => Flavor, :user => other_user).first
      expect(results).to match_array [project1_flavor, project2_flavor, flavor_other]
    end
  end

  private

  # separate them to match easier for failures
  def expect_counts(actual, expected_targets, expected_auth_count)
    expect(actual[1]).to eq(expected_auth_count)
    expect(actual[0].to_a).to match_array(expected_targets)
  end
end
