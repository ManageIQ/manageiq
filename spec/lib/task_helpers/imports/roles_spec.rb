RSpec.describe TaskHelpers::Imports::Roles do
  let(:data_dir)        { File.join(File.expand_path(__dir__), 'data', 'roles') }
  let(:role_file)       { 'Role_Import_Test.yaml' }
  let(:bad_role_file)   { 'Bad_Role_Import_Test.yml' }
  let(:role_one_name)   { 'Role Import Test' }
  let(:role_two_name)   { 'Role Import Test 2' }

  before do
    EvmSpecHelper.seed_specific_product_features(%w(
                                                   dashboard
                                                   dashboard_add
                                                   dashboard_view
                                                   host_compare
                                                   host_edit
                                                   host_scan
                                                   host_show_list
                                                   policy
                                                   vm
                                                   about
                                                 ))
  end

  describe "#import" do
    let(:options) { {:source => source} }

    describe "when the source is a directory" do
      let(:source) { data_dir }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::Roles.new.import(options)
        end.to_not output.to_stderr
        assert_test_role_one_present
        assert_test_role_two_present
      end
    end

    describe "when the source is a valid role file" do
      let(:source) { "#{data_dir}/#{role_file}" }

      it 'imports a specified role export file' do
        expect do
          TaskHelpers::Imports::Roles.new.import(options)
        end.to_not output.to_stderr

        assert_test_role_one_present
        expect(MiqUserRole.find_by(:name => role_two_name)).to be_nil
      end
    end

    describe "when the source is an invalid role file" do
      let(:source) { "#{data_dir}/#{bad_role_file}" }

      it 'fails to import a specified role file' do
        expect do
          TaskHelpers::Imports::Roles.new.import(options)
        end.to output.to_stderr
      end
    end
  end

  def assert_test_role_one_present
    r = MiqUserRole.find_by(:name => role_one_name)
    expect(r.name).to eq(role_one_name)
    expect(r.read_only).to be false
    expect(r.feature_identifiers).to eq(["about"])
    expect(r.settings).to eq(:restrictions=>{:vms=>:user_or_group})
  end

  def assert_test_role_two_present
    r = MiqUserRole.find_by(:name => role_two_name)
    expect(r.name).to eq(role_two_name)
    expect(r.read_only).to be false
    expect(r.feature_identifiers).to match_array(%w(dashboard vm))
    expect(r.settings).to be nil
  end
end
