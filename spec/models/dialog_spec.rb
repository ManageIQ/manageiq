require "spec_helper"

describe Dialog do
  describe ".seed" do
    let(:dialog_import_service) { auto_loaded_instance_double("DialogImportService") }
    let(:test_file_path) { Rails.root.join("spec/fixtures/files/dialogs") }
    let(:all_yaml_files) { test_file_path.join("{,*/**/}*.{yaml,yml}") }

    before do
      allow(DialogImportService).to receive(:new).and_return(dialog_import_service)
      allow(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file)
    end

    it "delegates to the dialog import service with a file in the default directory" do
      Dialog.with_constants(:DIALOG_DIR => test_file_path, :ALL_YAML_FILES => all_yaml_files) do
        expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
          test_file_path.join("seed_test.yaml").to_path)
        expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
          test_file_path.join("seed_test.yml").to_path)
        Dialog.seed
      end
    end

    it "delegates to the dialog import service with a file in a sub directory" do
      Dialog.with_constants(:DIALOG_DIR => test_file_path, :ALL_YAML_FILES => all_yaml_files) do
        expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
          test_file_path.join("service_dialogs/service_seed_test.yaml").to_path)
        expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
          test_file_path.join("service_dialogs/service_seed_test.yml").to_path)
        Dialog.seed
      end
    end

    it "delegates to the dialog import service with a symlinked file" do
      Dialog.with_constants(:DIALOG_DIR => test_file_path, :ALL_YAML_FILES => all_yaml_files) do
        expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
          test_file_path.join("service_dialog_symlink/service_seed_test.yaml").to_path)
        expect(dialog_import_service).to receive(:import_all_service_dialogs_from_yaml_file).with(
          test_file_path.join("service_dialog_symlink/service_seed_test.yml").to_path)
        Dialog.seed
      end
    end
  end

  it "#name" do
    dialog = FactoryGirl.create(:dialog, :label => 'dialog')
    expect(dialog.label).to eq(dialog.name)
  end

  context "validate label uniqueness" do
    it "with same label" do
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog') }.to_not raise_error
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog') }.to raise_error
    end

    it "with different labels" do
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog')   }.to_not raise_error
      expect { @dialog = FactoryGirl.create(:dialog, :label => 'dialog 1') }.to_not raise_error
    end
  end

  context "#create" do
    it "validates_presence_of name" do
      expect { FactoryGirl.create(:dialog) }.to raise_error
      expect { FactoryGirl.create(:dialog, :label => 'dialog') }.not_to raise_error

      expect { FactoryGirl.create(:dialog_tab) }.to raise_error
      expect { FactoryGirl.create(:dialog_tab, :label => 'tab') }.not_to raise_error

      expect { FactoryGirl.create(:dialog_group) }.to raise_error
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
      resource_action = FactoryGirl.create(:resource_action, :action => "Provision", :dialog => @dialog)
      expect { @dialog.destroy }.to raise_error
      expect(Dialog.count).to eq(1)
    end
  end

  context "#add_resource" do
    before(:each) do
      @dialog       = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab   = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => 'field_1')
    end

    it "dialog contain tabs" do
      @dialog.add_resource(@dialog_tab)
      @dialog.save
      expect(@dialog.dialog_tabs.size).to eq(1)
    end

    it "tabs contain groups" do
      @dialog_tab.add_resource(@dialog_group)
      @dialog_tab.save
      expect(@dialog_tab.dialog_groups.size).to eq(1)
    end

    it "groups contain fields" do
      @dialog_group.add_resource(@dialog_field)
      @dialog_group.save
      expect(@dialog_group.dialog_fields.size).to eq(1)
    end
  end

  context "#add_resource!" do
    before(:each) do
      @dialog       = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab   = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => 'field_1')
    end

    it "dialogs contain tabs" do
      @dialog.add_resource!(@dialog_tab)
      expect(@dialog.dialog_tabs.size).to eq(1)
    end

    it "tabs contain groups" do
      @dialog_tab.add_resource!(@dialog_group)
      expect(@dialog_tab.dialog_groups.size).to eq(1)
    end

    it "groups contain fields" do
      @dialog_group.add_resource!(@dialog_field)
      expect(@dialog_group.dialog_fields.size).to eq(1)
    end

    it "add controls" do
      text_box = FactoryGirl.create(:dialog_field_text_box, :label => 'text box', :name => 'text_box')
      @dialog_group.add_resource!(text_box)
      expect(@dialog_group.dialog_fields.size).to eq(1)

      tags = FactoryGirl.create(:dialog_field_tag_control, :label => 'tags', :name => 'tags')
      @dialog_group.add_resource!(tags)
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(2)

      button = FactoryGirl.create(:dialog_field_button, :label => 'button', :name => 'button')
      @dialog_group.add_resource!(button)
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(3)

      check_box = FactoryGirl.create(:dialog_field_text_box, :label => 'check box', :name => "check_box")
      @dialog_group.add_resource!(check_box)
      @dialog_group.reload
      expect(@dialog_group.dialog_fields.size).to eq(4)

      drop_down_list = FactoryGirl.create(:dialog_field_drop_down_list, :label => 'drop down list', :name => "drop_down_1")
      @dialog_group.add_resource!(drop_down_list)
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
      @dialog.add_resource(@dialog_tab)
      expect(@dialog.dialog_resources.size).to eq(1)
      @dialog.remove_all_resources
      expect(@dialog.dialog_resources.size).to eq(0)
    end

    it "tabs contain groups" do
      @dialog_tab.add_resource(@dialog_group)
      expect(@dialog_tab.dialog_resources.size).to eq(1)
      @dialog_tab.remove_all_resources
      expect(@dialog_tab.dialog_resources.size).to eq(0)
    end

    it "groups contain fields" do
      @dialog_group.add_resource(@dialog_field)
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

      @dialog.add_resource(@dialog_tab)
      @dialog_tab.add_resource(@dialog_group)
      @dialog_group.add_resource(@dialog_group_field)

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

      @dialog.add_resource(@dialog_tab)
      @dialog_tab.add_resource(@dialog_group)
      @dialog_group.add_resource(@dialog_field)
      @dialog_group.add_resource(@dialog_field2)

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

  context "#dialog_fields" do
    before(:each) do
      @dialog        = FactoryGirl.create(:dialog, :label => 'dialog')
      @dialog_tab    = FactoryGirl.create(:dialog_tab, :label => 'tab')
      @dialog_group  = FactoryGirl.create(:dialog_group, :label => 'group')
      @dialog_field  = FactoryGirl.create(:dialog_field, :label => 'field 1', :name => "field_1")
      @dialog_field2 = FactoryGirl.create(:dialog_field, :label => 'field 2', :name => "field_2")

      @dialog.add_resource(@dialog_tab)
      @dialog_tab.add_resource(@dialog_group)
      @dialog_group.add_resource(@dialog_field)
      @dialog_group.add_resource(@dialog_field2)

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
end
