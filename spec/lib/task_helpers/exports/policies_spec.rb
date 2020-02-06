RSpec.describe TaskHelpers::Exports::Policies do
  let(:guid) { "a61314d5-67bd-435f-9c82-b82226e0a7fe" }
  let(:guid2) { "ac7e2972-f2b2-4ebe-b29d-97eefaac7615" }

  let(:profile_export_attrs) do
    [
      {
        "MiqPolicy" => {
          "name"             => "a61314d5-67bd-435f-9c82-b82226e0a7fe",
          "description"      => "Test Compliance Policy",
          "expression"       => nil,
          "towhat"           => "Vm",
          "guid"             => "a61314d5-67bd-435f-9c82-b82226e0a7fe",
          "created_by"       => nil,
          "updated_by"       => nil,
          "notes"            => nil,
          "active"           => true,
          "mode"             => "compliance",
          "read_only"        => nil,
          "MiqPolicyContent" => [],
          "Condition"        => []
        }
      }
    ]
  end

  let(:policy_create_attrs) do
    {
      :description => "Test Compliance Policy",
      :name        => guid,
      :guid        => guid,
      :mode        => "compliance",
    }
  end

  let(:profile2_export_attrs) do
    [
      {
        "MiqPolicy" => {
          "name"             => "ac7e2972-f2b2-4ebe-b29d-97eefaac7615",
          "description"      => "Test Compliance Policy 2",
          "expression"       => nil,
          "towhat"           => "Host",
          "guid"             => "ac7e2972-f2b2-4ebe-b29d-97eefaac7615",
          "created_by"       => nil,
          "updated_by"       => nil,
          "notes"            => nil,
          "active"           => true,
          "mode"             => "control",
          "read_only"        => true,
          "MiqPolicyContent" => [],
          "Condition"        => []
        }
      }
    ]
  end

  let(:policy2_create_attrs) do
    {
      :description => "Test Compliance Policy 2",
      :name        => guid2,
      :guid        => guid2,
      :towhat      => "Host"
    }
  end

  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    FactoryBot.create(:miq_policy, policy_create_attrs)
    FactoryBot.create(:miq_policy_read_only, policy2_create_attrs)
  end

  after do
    FileUtils.remove_entry export_dir
  end

  it 'exports user policies to a given directory' do
    TaskHelpers::Exports::Policies.new.export(:directory => export_dir)
    file_contents = File.read("#{export_dir}/Test_Compliance_Policy.yaml")
    expect(YAML.safe_load(file_contents)).to eq(profile_export_attrs)
    expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(1)
  end

  it 'exports all policies to a given directory' do
    TaskHelpers::Exports::Policies.new.export(:directory => export_dir, :all => true)
    file_contents = File.read("#{export_dir}/Test_Compliance_Policy.yaml")
    file_contents2 = File.read("#{export_dir}/Test_Compliance_Policy_2.yaml")
    expect(YAML.safe_load(file_contents)).to eq(profile_export_attrs)
    expect(YAML.safe_load(file_contents2)).to eq(profile2_export_attrs)
  end
end
