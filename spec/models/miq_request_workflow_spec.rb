describe MiqRequestWorkflow do
  let(:workflow) { FactoryGirl.build(:miq_provision_workflow) }
  let(:ems) { FactoryGirl.create(:ext_management_system) }
  let(:resource_pool) { FactoryGirl.create(:resource_pool) }
  let(:ems_folder) { FactoryGirl.create(:ems_folder) }
  let(:datacenter) { FactoryGirl.create(:ems_folder, :type => "Datacenter") }

  context "#validate" do
    let(:dialog) { workflow.instance_variable_get(:@dialogs) }

    context "validation_method" do
      it "skips validation if no validation_method is defined" do
        expect(workflow.get_all_dialogs[:customize][:fields][:root_password][:validation_method]).to eq(nil)
        expect(workflow.validate({})).to be true
      end

      it "calls the validation_method if defined" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :validation_method, :some_validation_method)

        expect(workflow).to receive(:some_validation_method).once
        expect(workflow.validate({})).to be true
      end

      it "returns false when validation fails" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :validation_method, :some_validation_method)

        expect(workflow).to receive(:some_validation_method).and_return("Some Error")
        expect(workflow.validate({})).to be false
      end
    end

    context 'required_method is only run on visible fields' do
      it "field hidden" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required_method, :some_required_method)
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required, true)
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :display, :hide)

        expect(workflow).to_not receive(:some_required_method)
        expect(workflow.validate({})).to be true
      end

      it "field visible" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required_method, :some_required_method)
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :required, true)

        expect(workflow).to receive(:some_required_method).and_return("Some Error")
        expect(workflow.validate({})).to be false
      end
    end

    context "failures shouldn't be reverted" do
      it "validation_method" do
        dialog.store_path(:dialogs, :customize, :fields, :root_password, :validation_method, :some_validation_method)
        dialog.store_path(:dialogs, :customize, :fields, :root_password_2, :validation_method, :other_validation_method)

        expect(workflow).to receive(:some_validation_method).and_return("Some Error")
        expect(workflow).to receive(:other_validation_method)
        expect(workflow.validate({})).to be false
      end
    end
  end

  describe "#init_from_dialog" do
    let(:dialogs) { workflow.instance_variable_get(:@dialogs) }
    let(:init_values) { {} }

    context "when the initial values already have a value for the field name" do
      let(:init_values) { {:root_password => "root"} }

      it "does not modify the initial values" do
        workflow.init_from_dialog(init_values)
        expect(init_values).to eq(:root_password => "root")
      end
    end

    context "when the dialog fields ignore display" do
      before do
        dialogs[:dialogs].keys.each do |dialog_name|
          workflow.get_all_fields(dialog_name).each_pair do |_, field_values|
            field_values[:display] = :ignore
          end
        end
      end

      it "does not modify the initial values" do
        workflow.init_from_dialog(init_values)

        expect(init_values).to eq({})
      end
    end

    context "when the dialog field values default is not nil" do
      before do
        dialogs[:dialogs].keys.each do |dialog_name|
          workflow.get_all_fields(dialog_name).each_pair do |_, field_values|
            field_values[:default] = "not nil"
          end
        end
      end

      it "modifies the initial values with the default value" do
        workflow.init_from_dialog(init_values)

        expect(init_values).to eq(:root_password => "not nil")
      end
    end

    context "when the dialog field values default is nil" do
      before do
        dialogs[:dialogs].keys.each do |dialog_name|
          workflow.get_all_fields(dialog_name).each_pair do |_, field_values|
            field_values[:default] = nil
          end
        end
      end

      context "when the field values are a hash" do
        before do
          dialogs[:dialogs].keys.each do |dialog_name|
            workflow.get_all_fields(dialog_name).each_pair do |_, field_values|
              field_values[:values] = {:something => "test"}
            end
          end
        end

        it "uses the first field value" do
          workflow.init_from_dialog(init_values)

          expect(init_values).to eq(:root_password => [:something, "test"])
        end
      end

      context "when the field values are not a hash" do
        before do
          dialogs[:dialogs].keys.each do |dialog_name|
            workflow.get_all_fields(dialog_name).each_pair do |_, field_values|
              field_values[:values] = [%w(test 100), %w(test2 0)]
            end
          end
        end

        it "uses values as [value, description] for timezones aray" do
          workflow.init_from_dialog(init_values)

          expect(init_values).to eq(:root_password => [nil, "test2"])
        end
      end
    end
  end

  describe "#provisioning_tab_list" do
    let(:dialogs) { workflow.instance_variable_get(:@dialogs) }

    before do
      dialogs[:dialog_order] = [:test, :test2, :test3]
      dialogs[:dialogs][:test] = {:description => "test description", :display => :hide}
      dialogs[:dialogs][:test2] = {:description => "test description 2", :display => :ignore}
      dialogs[:dialogs][:test3] = {:description => "test description 3", :display => :edit}
    end

    it "returns a list of tabs without the hidden or ignored ones" do
      expect(workflow.provisioning_tab_list).to eq([{:name => "test3", :description => "test description 3"}])
    end
  end

  context "'allowed_*' methods" do
    let(:cluster)       { FactoryGirl.create(:ems_cluster, :ems_id => ems.id) }
    let(:ems)           { FactoryGirl.create(:ext_management_system) }
    let(:resource_pool) { FactoryGirl.create(:resource_pool, :ems_id => ems.id) }

    before { allow_any_instance_of(User).to receive(:get_timezone).and_return("UTC") }

    context "#allowed_clusters calls allowed_ci with the correct set of cluster ids" do
      it "missing sources" do
        cluster
        allow(workflow).to receive(:get_source_and_targets).and_return({})

        expect(workflow).to receive(:allowed_ci).with(:cluster, [:respool, :host, :folder], [])

        workflow.allowed_clusters
      end

      it "with valid sources" do
        FactoryGirl.create(:ems_cluster)
        allow(workflow).to receive(:get_source_and_targets).and_return(:ems => ems)

        expect(workflow).to receive(:allowed_ci).with(:cluster, [:respool, :host, :folder], [cluster.id])

        workflow.allowed_clusters
      end
    end

    context "#allowed_resource_pools calls allowed_ci with the correct set of resource_pool ids" do
      it "missing sources" do
        resource_pool
        allow(workflow).to receive(:get_source_and_targets).and_return({})

        expect(workflow).to receive(:allowed_ci).with(:respool, [:cluster, :host, :folder], [])

        workflow.allowed_resource_pools
      end

      it "with valid sources" do
        FactoryGirl.create(:resource_pool)
        allow(workflow).to receive(:get_source_and_targets).and_return(:ems => workflow.ci_to_hash_struct(ems))

        expect(workflow).to receive(:allowed_ci).with(:respool, [:cluster, :host, :folder], [resource_pool.id])

        workflow.allowed_resource_pools
      end
    end
  end

  context "#ci_to_hash_struct" do
    it("with a nil") { expect(workflow.ci_to_hash_struct(nil)).to be_nil }

    context "with collections" do
      let(:ems) { FactoryGirl.create(:ext_management_system) }

      it "an array" do
        arr = [FactoryGirl.create(:ems_cluster, :ems_id => ems.id), FactoryGirl.create(:ems_cluster, :ems_id => ems.id)]

        expect(workflow.ci_to_hash_struct(arr).length).to eq(2)
      end

      it "an ActiveRecord CollectionProxy" do
        FactoryGirl.create(:ems_cluster, :ems_id => ems.id)
        FactoryGirl.create(:ems_cluster, :ems_id => ems.id)

        expect(ems.clusters).to be_kind_of(ActiveRecord::Associations::CollectionProxy)
        expect(workflow.ci_to_hash_struct(ems.clusters).length).to eq(2)
      end
    end

    it "with an instance of a class that has a special format" do
      hs = workflow.ci_to_hash_struct(FactoryGirl.create(:vm_or_template))

      expect(hs.id).to               be_kind_of(Integer)
      expect(hs.evm_object_class).to eq(:VmOrTemplate)
      expect(hs.name).to             be_kind_of(String)
      expect(hs.platform).to         eq("unknown")
      expect(hs.snapshots).to        eq([])
    end

    it "with a regular class" do
      hs = workflow.ci_to_hash_struct(FactoryGirl.create(:configured_system))

      expect(hs.id).to               be_kind_of(Integer)
      expect(hs.evm_object_class).to eq(:ConfiguredSystem)
      expect(hs.name).to             be_kind_of(String)
    end
  end

  context "#validate regex" do
    let(:regex) { {:required_regex => "^n@test.com$"} }
    let(:regex_two) { {:required_regex => "^n$"} }
    let(:value_email) { 'n@test.com' }
    let(:value_no_email) { 'n' }

    it "returns nil when the value matches" do
      expect(workflow.validate_regex(nil, {}, {}, regex, value_email)).to be_nil
      expect(workflow.validate_regex(nil, {}, {}, regex_two, value_no_email)).to be_nil
    end

    it "returns a formatting message when value does not match regex" do
      expect(workflow.validate_regex(nil, {}, {}, regex, value_no_email)).to eq "'/' must be correctly formatted"
      expect(workflow.validate_regex(nil, {}, {}, regex_two, value_email)).to eq "'/' must be correctly formatted"
    end

    it "returns an error when no value exists" do
      expect(workflow.validate_regex(nil, {}, {}, regex, '')).to eq "'/' is required"
    end
  end

  context "#create_request" do
    it "sets requester_group" do
      values = {}
      request = workflow.create_request(values)
      expect(request.options[:requester_group]).to eq(workflow.requester.miq_group_description)
    end

    it "doesnt set owner_group" do
      values = {}
      request = workflow.create_request(values)
      expect(request.options[:owner_group]).not_to be
    end

    it "handles bad owner email" do
      values = {:owner_email => "bogus"}
      request = workflow.create_request(values)
      expect(request.options[:owner_group]).not_to be
    end

    it "sets owner group" do
      owner = FactoryGirl.create(:user_with_email, :miq_groups => [FactoryGirl.create(:miq_group)])
      values = {:owner_email => owner.email}
      request = workflow.create_request(values)
      expect(request.options[:owner_email]).to eq(owner.email)
      expect(request.options[:owner_group]).to eq(owner.current_group.description)
    end
  end

  context "#respool_to_folder" do
    before do
      resource_pool.ext_management_system = ems
      ems_folder.ext_management_system = ems
      attrs = ems_folder.attributes.merge(:object => ems_folder)
      xml_hash = XmlHash::Element.new('EmsFolder', attrs)
      hash = {"ResourcePool_#{resource_pool.id}" => xml_hash}
      workflow.instance_variable_set("@ems_xml_nodes", hash)
    end

    it "returns nil if :respool is nil" do
      src = {:respool => nil}
      expect(workflow.respool_to_folder(src)).to eq nil
    end

    it "returns an empty hash if no folders are found" do
      src = {:respool => resource_pool}
      expect(workflow.respool_to_folder(src)).to be_empty
    end
  end

  context "#folder_to_respool" do
    before do
      resource_pool.ext_management_system = ems
      ems_folder.ext_management_system = ems
      attrs = resource_pool.attributes.merge(:object => resource_pool, :ems => ems)
      xml_hash = XmlHash::Element.new('ResourcePool', attrs)
      hash = {"EmsFolder_#{ems_folder.id}" => xml_hash}
      workflow.instance_variable_set("@ems_xml_nodes", hash)
    end

    it "returns nil if :folder is nil" do
      src = {:folder => nil}
      expect(workflow.folder_to_respool(src)).to eq nil
    end

    it "returns an empty hash if no resource pools are found" do
      src = {:ems =>  ems, :folder => ems_folder}
      expect(workflow.folder_to_respool(src)).to be_empty
    end
  end

  context "#folder_to_datacenter" do
    before do
      datacenter.ext_management_system = ems
      attrs = datacenter.attributes.merge(:object => datacenter, :ems => ems)
      xml_hash = XmlHash::Element.new('EmsFolder', attrs)
      hash = {"EmsFolder_#{datacenter.id}" => xml_hash}
      workflow.instance_variable_set("@ems_xml_nodes", hash)
    end

    it "returns a datacenter" do
      src = {:ems => ems, :folder => datacenter}
      expect(workflow.folder_to_datacenter(src)).to eql(datacenter.id => datacenter.name)
    end
  end

  describe '#cast_value' do
    it 'integer' do
      expect(workflow.cast_value(1,   :integer)).to eq(1)
      expect(workflow.cast_value('1', :integer)).to eq(1)
    end

    it 'float' do
      expect(workflow.cast_value(1,     :float)).to eq(1.0)
      expect(workflow.cast_value('1',   :float)).to eq(1.0)
      expect(workflow.cast_value(2.1,   :float)).to eq(2.1)
      expect(workflow.cast_value('2.1', :float)).to eq(2.1)
    end

    it 'boolean' do
      expect(workflow.cast_value('true', :boolean)).to  be true
      expect(workflow.cast_value('t', :boolean)).to     be true

      expect(workflow.cast_value('false', :boolean)).to be false
      expect(workflow.cast_value('f', :boolean)).to     be false
      expect(workflow.cast_value('1', :boolean)).to     be false
      expect(workflow.cast_value('0', :boolean)).to     be false
      expect(workflow.cast_value('test', :boolean)).to  be false
    end

    it 'time' do
      time_str   = '2016-02-13 11:00:00.000000000 Z'
      time_match = Time.zone.parse(time_str)
      expect(workflow.cast_value(time_str, :time)).to eq(time_match)

      expect(workflow.cast_value('2016-02-13 11:00:00 Z', :time)).to eq(time_match)
    end

    it 'button' do
      expect(workflow.cast_value('data', :button)).to eq('data')
      expect(workflow.cast_value(1, :button)).to      eq(1)
    end

    it 'other' do
      expect(workflow.cast_value('data', :other)).to eq('data')
      expect(workflow.cast_value(1, :other)).to      eq(1)
    end
  end
end
