RSpec.describe TaskHelpers::Exports::PolicySets do
  let(:guid) { "a3734dcc-e25d-4164-ba95-1114568d491a" }
  let(:guid2) { "328593c3-a0a2-4a31-8d58-1a3eeef0ce95" }

  let(:policy_set_export_attrs) do
    [
      {
        "MiqPolicySet" => {
          "name"        => "a3734dcc-e25d-4164-ba95-1114568d491a",
          "description" => "Policy Set Export Test",
          "set_type"    => "MiqPolicySet",
          "guid"        => "a3734dcc-e25d-4164-ba95-1114568d491a",
          "read_only"   => nil,
          "set_data"    => nil,
          "mode"        => nil,
          "owner_type"  => nil,
          "owner_id"    => nil,
          "userid"      => nil,
          "group_id"    => nil,
          "MiqPolicy"   => []
        }
      }
    ]
  end

  let(:policy_set_create_attrs) do
    {
      :description => "Policy Set Export Test",
      :guid        => guid,
      :name        => guid
    }
  end

  let(:policy2_set_export_attrs) do
    [
      {
        "MiqPolicySet" => {
          "name"        => "328593c3-a0a2-4a31-8d58-1a3eeef0ce95",
          "description" => "Policy Set Export Test 2",
          "set_type"    => "MiqPolicySet",
          "guid"        => "328593c3-a0a2-4a31-8d58-1a3eeef0ce95",
          "read_only"   => true,
          "set_data"    => nil,
          "mode"        => nil,
          "owner_type"  => nil,
          "owner_id"    => nil,
          "userid"      => nil,
          "group_id"    => nil,
          "MiqPolicy"   => []
        }
      }
    ]
  end

  let(:policy2_set_create_attrs) do
    {
      :description => "Policy Set Export Test 2",
      :guid        => guid2,
      :name        => guid2
    }
  end

  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    FactoryBot.create(:miq_policy_set, policy_set_create_attrs)
    FactoryBot.create(:miq_policy_set_read_only, policy2_set_create_attrs)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  it 'exports user policy sets to a given directory' do
    TaskHelpers::Exports::PolicySets.new.export(:directory => export_dir)
    file_contents = File.read("#{export_dir}/Policy_Set_Export_Test.yaml")
    expect(YAML.safe_load(file_contents)).to eq(policy_set_export_attrs)
  end

  it 'exports all policy sets to a given directory' do
    TaskHelpers::Exports::PolicySets.new.export(:directory => export_dir, :all => true)
    file_contents = File.read("#{export_dir}/Policy_Set_Export_Test_2.yaml")
    expect(YAML.safe_load(file_contents)).to eq(policy2_set_export_attrs)
  end
end
