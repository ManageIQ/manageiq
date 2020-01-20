RSpec.describe TaskHelpers::Imports::PolicySets do
  let(:data_dir)            { File.join(File.expand_path(__dir__), 'data', 'policy_sets') }
  let(:policy_set_file)     { 'Policy_Profile_Import_Test.yaml' }
  let(:bad_policy_set_file) { 'Bad_Policy_Profile_Import_Test.yml' }
  let(:policy_set_one_guid) { "869d8a1c-eef8-4075-8f10-fb2b4198c20d" }
  let(:policy_set_two_guid) { "b762f0cb-8a50-4464-8ded-1f1ce341f3a7" }

  describe "#import" do
    let(:options) { {:source => source} }

    describe "when the source is a directory" do
      let(:source) { data_dir }
      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::PolicySets.new.import(options)
        end.to_not output.to_stderr

        assert_test_policy_set_one_present
        assert_test_policy_set_two_present
      end
    end

    describe "when the source is a valid policy set file" do
      let(:source) { "#{data_dir}/#{policy_set_file}" }

      it 'should import a specified policy set export file' do
        expect do
          TaskHelpers::Imports::PolicySets.new.import(options)
        end.to_not output.to_stderr

        assert_test_policy_set_one_present
        expect(MiqPolicySet.find_by(:guid => policy_set_two_guid)).to be_nil
      end
    end

    describe "when the source is an invalid policy set file" do
      let(:source) { "#{data_dir}/#{bad_policy_set_file}" }

      it 'should fail to import a specified policy set file' do
        expect do
          TaskHelpers::Imports::PolicySets.new.import(options)
        end.to output.to_stderr
      end
    end
  end

  def assert_test_policy_set_one_present
    p = MiqPolicySet.find_by(:guid => policy_set_one_guid)
    expect(p.description).to eq("Policy Profile Import Test")
    b = p.miq_policies.first
    expect(b.guid).to eq("7562ca69-a00d-4017-be8f-d31d39a07deb")
    expect(b.description).to eq("Test Compliance Policy")
    expect(b.active).to be true
  end

  def assert_test_policy_set_two_present
    p = MiqPolicySet.find_by(:guid => policy_set_two_guid)
    expect(p.description).to eq("Policy Profile Import Test 2")
    b = p.miq_policies.first
    expect(b.guid).to eq("b314df11-9790-47a1-8e12-14fa124cc862")
    expect(b.description).to eq("Test Control Policy")
    expect(b.active).to be true
  end
end
