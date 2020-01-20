RSpec.describe TaskHelpers::Imports::GenericObjectDefinitions do
  describe "#import" do
    let(:data_dir) { File.join(File.expand_path(__dir__), 'data', 'generic_object_definitions') }
    let(:options) { { :source => source, :overwrite => overwrite } }
    let(:god_name1) { "Apep" }
    let(:god_name2) { "Apophis" }
    let(:god_file1) { "apep.yaml" }
    let(:god_file2) { "apophis.yaml" }
    let(:god_desc1) { "Ancient Egyptian deity who embodied chaos" }
    let(:god_desc1_updated) { "Updated description" }
    let(:runt_err_file) { "god_runtime_error.yml" }
    let(:attr_err_file) { "god_attr_error.yml" }
    let(:god_prop1) do
      {
        :attributes   => {
          'weapon'     => :string,
          'is_tired'   => :boolean,
          'created'    => :datetime,
          'retirement' => :datetime
        },
        :associations => { 'cloud_tenant' => 'CloudTenant' },
        :methods      => ['kick', 'laugh_at', 'punch', 'parseltongue']
      }
    end

    describe "when the source is a directory" do
      let(:source) { data_dir }
      let(:overwrite) { true }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::GenericObjectDefinitions.new.import(options)
        end.to_not output.to_stderr
        expect(GenericObjectDefinition.all.count).to eq(2)
        assert_test_god_one_present
        assert_test_god_two_present
      end
    end

    describe "when the source is a file" do
      let(:source) { "#{data_dir}/#{god_file1}" }
      let(:overwrite) { true }

      it 'imports a specified file' do
        expect do
          TaskHelpers::Imports::GenericObjectDefinitions.new.import(options)
        end.to_not output.to_stderr
        expect(GenericObjectDefinition.all.count).to eq(1)
        assert_test_god_one_present
      end
    end

    describe "when the source file modifies an existing generic object definition" do
      let(:update_file) { "apep_update.yml" }
      let(:source) { "#{data_dir}/#{update_file}" }

      before do
        TaskHelpers::Imports::GenericObjectDefinitions.new.import(:source => "#{data_dir}/#{god_file1}")
      end

      context 'overwrite is true' do
        let(:overwrite) { true }

        it 'overwrites an existing generic object definition' do
          expect do
            TaskHelpers::Imports::GenericObjectDefinitions.new.import(options)
          end.to_not output.to_stderr
          assert_test_god_one_modified
        end
      end

      context 'overwrite is false' do
        let(:overwrite) { false }

        it 'does not overwrite an existing generic object definition' do
          expect do
            TaskHelpers::Imports::GenericObjectDefinitions.new.import(options)
          end.to_not output.to_stderr
          assert_test_god_one_present
        end
      end
    end

    describe "when the source file has invalid settings" do
      let(:overwrite) { true }

      context "when the object type is invalid" do
        let(:source) { "#{data_dir}/#{runt_err_file}" }

        it 'generates an error' do
          expect do
            TaskHelpers::Imports::GenericObjectDefinitions.new.import(options)
          end.to output(/Incorrect format/).to_stderr
        end
      end

      context "when an attribute is invalid" do
        let(:source) { "#{data_dir}/#{attr_err_file}" }

        it 'generates an error' do
          expect do
            TaskHelpers::Imports::GenericObjectDefinitions.new.import(options)
          end.to output(/unknown attribute 'invalid_attribute'/).to_stderr
        end
      end
    end
  end

  def assert_test_god_one_present
    god = GenericObjectDefinition.find_by(:name => god_name1)
    expect(god.name).to eq(god_name1)
    expect(god.description).to eq(god_desc1)
    expect(god.properties).to eq(god_prop1)
  end

  def assert_test_god_two_present
    god = GenericObjectDefinition.find_by(:name => god_name2)
    expect(god.name).to eq(god_name2)
    expect(god.description).to eq(god_desc1)
    expect(god.properties).to eq(god_prop1)
  end

  def assert_test_god_one_modified
    god = GenericObjectDefinition.find_by(:name => god_name1)
    expect(god.name).to eq(god_name1)
    expect(god.description).to eq(god_desc1_updated)
    god_prop1[:methods] << 'updated_method'
    expect(god.properties).to eq(god_prop1)
  end
end
