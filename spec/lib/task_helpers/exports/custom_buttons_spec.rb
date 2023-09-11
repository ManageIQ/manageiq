RSpec.describe TaskHelpers::Exports::CustomButtons do
  let(:export_dir) { Dir.mktmpdir('miq_exp_dir') }

  after do
    FileUtils.remove_entry export_dir
  end

  context "simple CustomButtonSet and direct CustomButton" do
    let!(:custom_button)     { FactoryBot.create(:custom_button, :name => "export_test_button", :description => "Export Test", :applies_to_class => "Vm") }
    let!(:custom_button2)    { FactoryBot.create(:custom_button, :name => "export_test_button2", :description => "Export Test", :applies_to_class => "Service") }
    let!(:custom_button_set) { FactoryBot.create(:custom_button_set, :name => "custom_button_set", :description => "Default Export Test") }

    let(:custom_button_export_test) do
      {"custom_button_set" => [{
        "attributes" => {
          "name"        => "custom_button_set",
          "description" => "Default Export Test",
          "set_type"    => "CustomButtonSet",
          "guid"        => custom_button_set.guid,
          "read_only"   => nil,
          "set_data"    => {:button_order => []},
          "mode"        => nil,
          "owner_type"  => nil,
          "owner_id"    => nil,
          "userid"      => nil,
          "group_id"    => nil
        },
        "children"   => {
          "custom_button" => [{
            "attributes" => {
              "guid"                  => custom_button.guid,
              "description"           => "Export Test",
              "applies_to_class"      => "Vm",
              "visibility_expression" => nil,
              "options"               => {},
              "userid"                => nil,
              "wait_for_complete"     => nil,
              "name"                  => "export_test_button",
              "visibility"            => nil,
              "applies_to_id"         => nil,
              "enablement_expression" => nil,
              "disabled_text"         => nil
            }
          }]
        }
      }],
       "custom_button"     => [{
         "attributes" => {
           "guid"                  => custom_button2.guid,
           "description"           => "Export Test",
           "applies_to_class"      => "Service",
           "visibility_expression" => nil,
           "options"               => {},
           "userid"                => nil,
           "wait_for_complete"     => nil,
           "name"                  => "export_test_button2",
           "visibility"            => nil,
           "applies_to_id"         => nil,
           "enablement_expression" => nil,
           "disabled_text"         => nil
         }
       }]}
    end

    before do
      custom_button_set.add_member(custom_button)
    end

    it 'exports custom buttons to a given directory' do
      TaskHelpers::Exports::CustomButtons.new.export(:directory => export_dir)
      file_contents = File.read("#{export_dir}/CustomButtons.yaml")

      expect(YAML.safe_load(file_contents, :permitted_classes => [Symbol])).to contain_exactly(*custom_button_export_test)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
    end
  end

  context "with multiple button sets" do
    let!(:custom_button1)     { FactoryBot.create(:custom_button,     :name => "button1", :description => "Button One", :applies_to_class => "Vm") }
    let!(:custom_button2)     { FactoryBot.create(:custom_button,     :name => "button2", :description => "Button Two", :applies_to_class => "Vm") }
    let!(:custom_button_set1) { FactoryBot.create(:custom_button_set, :name => "set1",    :description => "Set One") }
    let!(:custom_button_set2) { FactoryBot.create(:custom_button_set, :name => "set2",    :description => "Set Two") }

    before do
      custom_button_set1.add_member(custom_button1)
      custom_button_set2.add_member(custom_button2)
    end

    let(:multi_custom_button_export_test) do
      {
        "custom_button_set" => [
          {
            "attributes" => {
              "name"        => "set1",
              "description" => "Set One",
              "set_type"    => "CustomButtonSet",
              "guid"        => custom_button_set1.guid,
              "read_only"   => nil,
              "set_data"    => {:button_order => []},
              "mode"        => nil,
              "owner_type"  => nil,
              "owner_id"    => nil,
              "userid"      => nil,
              "group_id"    => nil
            },
            "children"   => {
              "custom_button" => [{
                "attributes" => {
                  "guid"                  => custom_button1.guid,
                  "description"           => "Button One",
                  "applies_to_class"      => "Vm",
                  "visibility_expression" => nil,
                  "options"               => {},
                  "userid"                => nil,
                  "wait_for_complete"     => nil,
                  "name"                  => "button1",
                  "visibility"            => nil,
                  "applies_to_id"         => nil,
                  "enablement_expression" => nil,
                  "disabled_text"         => nil
                }
              }],
            },
          },
          {
            "attributes" => {
              "name"        => "set2",
              "description" => "Set Two",
              "set_type"    => "CustomButtonSet",
              "guid"        => custom_button_set2.guid,
              "read_only"   => nil,
              "set_data"    => {:button_order => []},
              "mode"        => nil,
              "owner_type"  => nil,
              "owner_id"    => nil,
              "userid"      => nil,
              "group_id"    => nil
            },
            "children"   => {
              "custom_button" => [{
                "attributes" => {
                  "guid"                  => custom_button2.guid,
                  "description"           => "Button Two",
                  "applies_to_class"      => "Vm",
                  "visibility_expression" => nil,
                  "options"               => {},
                  "userid"                => nil,
                  "wait_for_complete"     => nil,
                  "name"                  => "button2",
                  "visibility"            => nil,
                  "applies_to_id"         => nil,
                  "enablement_expression" => nil,
                  "disabled_text"         => nil
                }
              }]
            }
          }
        ],
        "custom_button"     => []
      }
    end

    it 'exports custom buttons to a given directory' do
      TaskHelpers::Exports::CustomButtons.new.export(:directory => export_dir)
      file_contents = File.read("#{export_dir}/CustomButtons.yaml")

      expect(YAML.safe_load(file_contents, :permitted_classes => [Symbol])).to contain_exactly(*multi_custom_button_export_test)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
    end
  end

  context "with buttons with resource_actions and dialogs" do
    let!(:custom_button1)     { FactoryBot.create(:custom_button,     :name => "button1", :description => "Button One", :applies_to_class => "Vm", :resource_action => resource_action1) }
    let!(:custom_button2)     { FactoryBot.create(:custom_button,     :name => "button2", :description => "Button Two", :applies_to_class => "Vm", :resource_action => resource_action2) }
    let!(:custom_button_set1) { FactoryBot.create(:custom_button_set, :name => "set1",    :description => "Set One") }

    let(:resource_action1) do
      FactoryBot.build(:resource_action,
                       :ae_namespace => "NAMESPACE",
                       :ae_class     => "CLASS",
                       :ae_instance  => "INSTANCE")
    end

    let(:resource_action2) do
      FactoryBot.build(:resource_action,
                       :ae_namespace => "SYSTEM",
                       :ae_class     => "PROCESS",
                       :ae_instance  => "Request",
                       :dialog       => FactoryBot.create(:dialog, :name => "label1"))
    end

    before do
      custom_button_set1.add_member(custom_button1)
    end

    let(:custom_button_with_dialogs_export_test) do
      {
        "custom_button_set" => [{
          "attributes" => {
            "name"        => "set1",
            "description" => "Set One",
            "set_type"    => "CustomButtonSet",
            "guid"        => custom_button_set1.guid,
            "read_only"   => nil,
            "set_data"    => {:button_order => []},
            "mode"        => nil,
            "owner_type"  => nil,
            "owner_id"    => nil,
            "userid"      => nil,
            "group_id"    => nil
          },
          "children"   => {
            "custom_button" => [{
              "attributes"   => {
                "guid"                  => custom_button1.guid,
                "description"           => "Button One",
                "applies_to_class"      => "Vm",
                "visibility_expression" => nil,
                "options"               => {},
                "userid"                => nil,
                "wait_for_complete"     => nil,
                "name"                  => "button1",
                "visibility"            => nil,
                "applies_to_id"         => nil,
                "enablement_expression" => nil,
                "disabled_text"         => nil
              },
              "associations" => {
                "resource_action" => [{
                  "attributes" => {
                    "action"                      => nil,
                    "ae_namespace"                => "NAMESPACE",
                    "ae_class"                    => "CLASS",
                    "ae_instance"                 => "INSTANCE",
                    "ae_message"                  => nil,
                    "ae_attributes"               => {},
                    "configuration_template_id"   => nil,
                    "configuration_template_type" => nil,
                    "configuration_script_id"     => nil,
                    "resource_type"               => "CustomButton"
                  }
                }]
              }
            }],
          },
        }],
        "custom_button" => [{
          "attributes" => {
            "guid"                  => custom_button2.guid,
            "description"           => "Button Two",
            "applies_to_class"      => "Vm",
            "visibility_expression" => nil,
            "options"               => {},
            "userid"                => nil,
            "wait_for_complete"     => nil,
            "name"                  => "button2",
            "visibility"            => nil,
            "applies_to_id"         => nil,
            "enablement_expression" => nil,
            "disabled_text"         => nil
          },
          "associations" => {
            "resource_action" => [{
              "attributes" => {
                "action"                      => nil,
                "resource_type"               => "CustomButton",
                "ae_namespace"                => "SYSTEM",
                "ae_class"                    => "PROCESS",
                "ae_instance"                 => "Request",
                "ae_message"                  => nil,
                "ae_attributes"               => {},
                "configuration_template_id"   => nil,
                "configuration_template_type" => nil,
                "configuration_script_id"     => nil,
                "dialog_label"                => "label1"
              }
            }]
          }
        }]
      }
    end

    it 'exports custom buttons to a given directory' do
      TaskHelpers::Exports::CustomButtons.new.export(:directory => export_dir)
      file_contents = File.read("#{export_dir}/CustomButtons.yaml")

      expect(YAML.safe_load(file_contents, :permitted_classes => [Symbol])).to contain_exactly(*custom_button_with_dialogs_export_test)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
    end
  end
end
