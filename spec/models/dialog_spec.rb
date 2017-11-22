describe Dialog do
  describe ".seed" do
    let(:dialog_import_service) { double("DialogImportService") }
    let(:test_file_path) { "spec/fixtures/files/dialogs" }

    before do
      allow(DialogImportService).to receive(:new).and_return(dialog_import_service)
      allow(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file)
    end

    it "seed files from plugins" do
      mock_engine = double(:root => Rails.root)
      expect(Vmdb::Plugins.instance).to receive(:vmdb_plugins).and_return([mock_engine])

      stub_const('Dialog::DIALOG_DIR_PLUGIN', test_file_path)
      stub_const('Dialog::DIALOG_DIR_CORE', 'non-existent-dir')
      expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
        Rails.root.join(test_file_path, "seed_test.yaml").to_path
      )
      expect(mock_engine).to receive(:root)
      described_class.seed
    end
  end

  it "#name" do
    dialog = FactoryGirl.create(:dialog, :label => 'dialog')
    expect(dialog.label).to eq(dialog.name)
  end

  describe "#content" do
    it "returns the serialized content" do
      dialog = FactoryGirl.create(:dialog, :description => "foo", :label => "bar")
      expect(dialog.content).to match([hash_including("description" => "foo", "label" => "bar")])
    end
  end

  context "validate label uniqueness" do
    it "with same label" do
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog') }.to_not raise_error
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog') }
        .to raise_error(ActiveRecord::RecordInvalid, /Label is not unique within region/)
    end

    it "with different labels" do
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog')   }.to_not raise_error
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog 1') }.to_not raise_error
    end
  end

  context "#create" do
    it "validates_presence_of name" do
      expect do
        FactoryGirl.create(:dialog, :label => nil)
      end.to raise_error(ActiveRecord::RecordInvalid, /Label can't be blank/)
      expect { FactoryGirl.create(:dialog, :label => 'dialog') }.not_to raise_error

      expect do
        FactoryGirl.create(:dialog_tab, :label => nil)
      end.to raise_error(ActiveRecord::RecordInvalid, /Label can't be blank/)
      expect { FactoryGirl.create(:dialog_tab, :label => 'tab') }.not_to raise_error

      expect do
        FactoryGirl.create(:dialog_group, :label => nil)
      end.to raise_error(ActiveRecord::RecordInvalid, /Label can't be blank/)
      expect { FactoryGirl.create(:dialog_group, :label => 'group') }.not_to raise_error
    end
  end

  context "#destroy" do
    before(:each) do
      @dialog = FactoryGirl.create(:dialog, :label => 'dialog')
    end

    it "destroy without resource_action association" do
      expect(@dialog.destroy).to be_truthy
      expect(Dialog.count).to eq(0)
    end

    it "destroy with resource_action association" do
      FactoryGirl.create(:resource_action, :action => "Provision", :dialog => @dialog)
      @dialog.reload
      expect { @dialog.destroy }
        .to raise_error(RuntimeError, /Dialog cannot be deleted.*connected to other components/)
      expect(Dialog.count).to eq(1)
    end
  end

  describe "dialog structures" do
    before(:each) do
      @dialog       = FactoryGirl.build(:dialog, :label => 'dialog')
      @dialog_tab   = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => 'field_1')
    end

    it "dialogs contain tabs" do
      @dialog_group.dialog_fields << @dialog_field
      @dialog_tab.dialog_groups << @dialog_group
      @dialog.dialog_tabs << @dialog_tab
      expect(@dialog.dialog_tabs.size).to eq(1)
    end

    it "tabs contain groups" do
      @dialog_tab.dialog_groups << @dialog_group
      expect(@dialog_tab.dialog_groups.size).to eq(1)
    end

    it "groups contain fields" do
      @dialog_group.dialog_fields << @dialog_field
      expect(@dialog_group.dialog_fields.size).to eq(1)
    end

    it "add controls" do
      text_box = FactoryGirl.create(:dialog_field_text_box, :label => 'text box', :name => 'text_box')
      @dialog_group.dialog_fields << text_box
      expect(@dialog_group.dialog_fields.size).to eq(1)

      tags = FactoryGirl.create(:dialog_field_tag_control, :label => 'tags', :name => 'tags')
      @dialog_group.dialog_fields << tags
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(2)

      button = FactoryGirl.create(:dialog_field_button, :label => 'button', :name => 'button')
      @dialog_group.dialog_fields << button
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(3)

      check_box = FactoryGirl.create(:dialog_field_text_box, :label => 'check box', :name => "check_box")
      @dialog_group.dialog_fields << check_box
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(4)

      drop_down_list = FactoryGirl.create(:dialog_field_drop_down_list, :label => 'drop down list', :name => "drop_down_1")
      @dialog_group.dialog_fields << drop_down_list
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(5)
    end
  end

  context "#remove_all_resources" do
    before(:each) do
      @dialog       = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab   = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => "field_1")
    end

    it "dialogs contain tabs" do
      @dialog.dialog_tabs << @dialog_tab
      expect(@dialog.dialog_resources.size).to eq(1)
      @dialog.remove_all_resources
      expect(@dialog.dialog_resources.size).to eq(0)
    end

    it "tabs contain groups" do
      @dialog_tab.dialog_groups << @dialog_group
      expect(@dialog_tab.dialog_resources.size).to eq(1)
      @dialog_tab.remove_all_resources
      expect(@dialog_tab.dialog_resources.size).to eq(0)
    end

    it "groups contain fields" do
      @dialog_group.dialog_fields << @dialog_field
      expect(@dialog_group.dialog_resources.size).to eq(1)
      @dialog_group.remove_all_resources
      expect(@dialog_group.dialog_resources.size).to eq(0)
    end
  end

  context "remove resources" do
    before(:each) do
      @dialog             = FactoryGirl.create(:dialog,       :label => 'dialog')
      @dialog_tab         = FactoryGirl.create(:dialog_tab,   :label => 'tab')
      @dialog_group       = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_group_field = FactoryGirl.create(:dialog_field, :label => 'group field', :name => "group field")

      @dialog.dialog_tabs << @dialog_tab
      @dialog_tab.dialog_groups << @dialog_group
      @dialog_group.dialog_fields << @dialog_group_field

      @dialog.save
      @dialog_tab.save
      @dialog_group.save
    end

    it "dialog" do
      @dialog.destroy
      expect(Dialog.count).to eq(0)
      expect(DialogTab.count).to eq(0)
      expect(DialogGroup.count).to eq(0)
      expect(DialogField.count).to eq(0)
    end

    it "dialog_tab" do
      @dialog_tab.destroy
      expect(Dialog.count).to eq(1)
      expect(DialogTab.count).to eq(0)
      expect(DialogGroup.count).to eq(0)
      expect(DialogField.count).to eq(0)
    end

    it "dialog_group" do
      @dialog_group.destroy
      expect(Dialog.count).to eq(1)
      expect(DialogTab.count).to eq(1)
      expect(DialogGroup.count).to eq(0)
      expect(DialogField.count).to eq(0)

      @dialog_tab.destroy
      expect(Dialog.count).to eq(1)
      expect(DialogTab.count).to eq(0)
    end
  end

  context "#each_field" do
    before(:each) do
      @dialog        = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab    = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group  = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field  = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => "field_1")
      @dialog_field2 = FactoryGirl.create(:dialog_field, :label => 'field 2', :name => "field_2")

      @dialog.dialog_tabs << @dialog_tab
      @dialog_tab.dialog_groups << @dialog_group
      @dialog_group.dialog_fields << @dialog_field
      @dialog_group.dialog_fields << @dialog_field2

      @dialog_group.save
      @dialog_tab.save
      @dialog.save
    end

    it "dialog_group" do
      count = 0
      @dialog_group.each_dialog_field { |_df| count += 1 }
      expect(count).to eq(2)
    end

    it "dialog_tab" do
      count = 0
      @dialog_tab.each_dialog_field { |_df| count += 1 }
      expect(count).to eq(2)
    end

    it "dialog" do
      count = 0
      @dialog.each_dialog_field { |_df| count += 1 }
      expect(count).to eq(2)
    end
  end

  describe '#update_tabs' do
    let(:dialog_field) { FactoryGirl.create_list(:dialog_field, 1, :label => 'field') }
    let(:dialog_group) { FactoryGirl.create_list(:dialog_group, 1, :label => 'group', :dialog_fields => dialog_field) }
    let(:dialog_tab) { FactoryGirl.create_list(:dialog_tab, 1, :label => 'tab', :dialog_groups => dialog_group) }
    let(:dialog) { FactoryGirl.create(:dialog, :label => 'dialog', :dialog_tabs => dialog_tab) }

    let(:updated_content) do
      [
        {
          'id'            => dialog_tab.first.compressed_id,
          'label'         => 'updated_label',
          'dialog_groups' => [
            { 'id'            => dialog_group.first.compressed_id,
              'dialog_tab_id' => dialog_tab.first.compressed_id,
              'dialog_fields' =>
                                 [{
                                   'id'              => dialog_field.first.id,
                                   'dialog_group_id' => dialog_group.first.compressed_id
                                 }] },
            {
              'label'         => 'group 2',
              'dialog_fields' => [{
                'name'  => 'dialog_field',
                'label' => 'field_label'
              }]
            }
          ]
        },
        {
          'label'         => 'new tab',
          'dialog_groups' => [
            {
              'label'         => 'a new group',
              'dialog_fields' => [
                {'name' => 'new field', 'label' => 'field'}
              ]
            }
          ]
        }
      ]
    end

    context 'a collection of dialog tabs containing one with an id and one without an id' do
      it 'updates the dialog_tab with an id' do
        dialog.update_tabs(updated_content)
        expect(dialog.reload.dialog_tabs.collect(&:label)).to match_array(['updated_label', 'new tab'])
      end

      it 'creates the dialog tab from the dialog tabs without an id' do
        dialog.update_tabs(updated_content)
        expect(dialog.reload.dialog_tabs.count).to eq(2)
      end
    end

    context 'with a dialog tab removed from the dialog tabs collection' do
      let(:updated_content) do
        [
          'id'            => dialog_tab.first.id,
          'dialog_groups' => [
            { 'id' => dialog_group.first.id, 'dialog_fields' => [{ 'id' => dialog_field.first.id }] }
          ]
        ]
      end

      before do
        dialog.dialog_tabs << FactoryGirl.create(:dialog_tab)
      end

      it 'deletes the removed dialog_tab' do
        expect do
          dialog.update_tabs(updated_content)
        end.to change(dialog.reload.dialog_tabs, :count).by(-1)
      end
    end

    context 'compresssed ids' do
      let(:updated_content) do
        [
          {
            'id'            => dialog_tab.first.id,
            'label'         => 'updated_label_foo',
            'dialog_groups' => [
              { 'id'            => dialog_group.first.compressed_id,
                'label'         => 'updated_label_bar',
                'dialog_fields' =>
                                   [{'id' => dialog_field.first.compressed_id, 'label' => 'updated_label_baz'}]}
            ]
          }
        ]
      end

      before do
        dialog.dialog_tabs << FactoryGirl.create(:dialog_tab)
      end

      it 'updates the content' do
        dialog.update_tabs(updated_content)

        tab = dialog.dialog_tabs.first
        group = tab.dialog_groups.first
        expect(tab.label).to eq('updated_label_foo')
        expect(group.label).to eq('updated_label_bar')
        expect(group.dialog_fields.first.label).to eq('updated_label_baz')
      end
    end
  end

  context "#dialog_fields" do
    before(:each) do
      @dialog        = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab    = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group  = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field  = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => "field_1")
      @dialog_field2 = FactoryGirl.create(:dialog_field, :label => 'field 2', :name => "field_2")

      @dialog.dialog_tabs << @dialog_tab
      @dialog.dialog_tabs << FactoryGirl.create(:dialog_tab, :label => 'tab2')
      @dialog_tab.dialog_groups << @dialog_group
      @dialog_tab.dialog_groups << FactoryGirl.create(:dialog_group, :label => 'group2')
      @dialog_group.dialog_fields << @dialog_field
      @dialog_group.dialog_fields << @dialog_field2

      @dialog_group.save
      @dialog_tab.save
      @dialog.save
    end

    it "dialog_group" do
      expect(@dialog_group.dialog_fields.count).to eq(2)
    end

    it "dialog_tab" do
      expect(@dialog_tab.dialog_fields.count).to eq(2)
    end

    it "dialog" do
      expect(@dialog.dialog_fields.count).to eq(2)
    end
  end

  context "validate children before save" do
    let(:dialog) { FactoryGirl.build(:dialog, :label => 'dialog') }

    it "fails without tab" do
      expect { dialog.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Dialog #{dialog.label} must have at least one Tab")
    end

    context "unique field names" do
      before do
        dialog.dialog_tabs << FactoryGirl.create(:dialog_tab, :label => 'tab')
        dialog.dialog_tabs.first.dialog_groups << FactoryGirl.create(:dialog_group, :label => 'group')
        dialog.dialog_tabs.first.dialog_groups.first.dialog_fields << FactoryGirl.create(:dialog_field, :label => 'field 1', :name => 'field1')
      end

      it "fails with two identical field names on different groups" do
        dialog.dialog_tabs.first.dialog_groups << FactoryGirl.create(:dialog_group, :label => 'group2')
        dialog.dialog_tabs.first.dialog_groups.last.dialog_fields << FactoryGirl.create(:dialog_field, :label => 'field 3', :name => 'field1')
        expect { dialog.save! }
          .to raise_error(ActiveRecord::RecordInvalid, /Dialog field name cannot be duplicated on a dialog: field1/)
      end

      it "fails with two identical field names on same group" do
        dialog.dialog_tabs.first.dialog_groups.first.dialog_fields << FactoryGirl.create(:dialog_field, :label => 'field 3', :name => 'field1')
        expect { dialog.save! }
          .to raise_error(ActiveRecord::RecordInvalid, /Dialog field name cannot be duplicated on a dialog: field1/)
      end
    end

    it "validates with tab" do
      dialog.dialog_tabs << FactoryGirl.create(:dialog_tab, :label => 'tab')
      expect_any_instance_of(DialogTab).to receive(:valid?)
      expect(dialog.errors.full_messages).to be_empty
      dialog.validate_children
    end
  end

  describe "#deep_copy" do
    let(:dialog_service) { Dialog::OrchestrationTemplateServiceDialog.new }
    let(:template)       { FactoryGirl.create(:orchestration_template).tap { |t| allow(t).to receive(:parameter_groups).and_return([]) } }
    let(:dialog)         { dialog_service.create_dialog('test', template) }

    it "clones the dialog and all containing components" do
      dialog_new = dialog.deep_copy(:name => 'test_cloned')
      num_dialogs = Dialog.count
      num_tabs = DialogTab.count
      num_groups = DialogGroup.count
      num_fields = DialogField.count
      num_actions = ResourceAction.count

      dialog_new.save!
      expect(Dialog.count).to eq(num_dialogs * 2)
      expect(DialogTab.count).to eq(num_tabs * 2)
      expect(DialogGroup.count).to eq(num_groups * 2)
      expect(DialogField.count).to eq(num_fields * 2)
      expect(ResourceAction.count).to eq(num_actions * 2)
    end
  end

  describe "#init_fields_with_values_for_request" do
    let(:dialog) { described_class.new(:dialog_tabs => [dialog_tab]) }
    let(:dialog_tab) { DialogTab.new(:dialog_groups => [dialog_group]) }
    let(:dialog_group) { DialogGroup.new(:dialog_fields => [dialog_field1]) }
    let(:dialog_field1) { DialogField.new(:value => "123", :name => "field1") }

    context "when the values use the automate key name" do
      it "initializes the fields with the given values" do
        values = {"dialog_field1" => "field 1 new value"}
        dialog.init_fields_with_values_for_request(values)
        expect(dialog_field1.value).to eq("field 1 new value")
      end
    end

    context "when the values use the regular name" do
      it "initializes the fields with the given values" do
        values = {"field1" => "field 1 new value"}
        dialog.init_fields_with_values_for_request(values)
        expect(dialog_field1.value).to eq("field 1 new value")
      end
    end
  end
end
