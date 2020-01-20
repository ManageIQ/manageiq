RSpec.describe TaskHelpers::Imports::Tags do
  let(:data_dir)        { File.join(File.expand_path(__dir__), 'data', 'tags') }
  let(:tag_file1)       { 'Import_Test.yaml' }
  let(:tag_file2)       { 'Location.yaml' }
  let(:bad_tag_file1)   { 'Tag_Test_Fail_Cat.yml' }
  let(:bad_tag_file2)   { 'Tag_Test_Fail_Cat_Yaml.yml' }
  let(:bad_tag_file3)   { 'Tag_Test_Fail_Entry.yml' }
  let(:tag_one_name)    { 'import_test' }
  let(:tag_two_name)    { 'location' }
  let(:tag_one_entry)   { '/managed/import_test/1' }
  let(:tag_two_entry)   { '/managed/location/phoenix' }
  let(:tag_two_cat)     { '/managed/location' }
  let(:tag_two_desc)    { 'Location Imported' }

  describe "#import" do
    let(:options) { {:source => source} }

    describe "when the source is a directory" do
      let(:source) { data_dir }

      it 'imports all .yaml files in a specified directory' do
        expect do
          TaskHelpers::Imports::Tags.new.import(options)
        end.to_not output.to_stderr
        assert_test_tag_one_present
        assert_test_tag_two_present
        assert_test_tag_category_count
      end
    end

    describe "when the source is a valid tag file" do
      let(:source) { "#{data_dir}/#{tag_file1}" }

      it 'imports a specified tag export file' do
        expect do
          TaskHelpers::Imports::Tags.new.import(options)
        end.to_not output.to_stderr

        assert_test_tag_one_present
        expect(Tag.exists?(tag_two_cat)).to be_falsey
      end
    end

    describe "when the tag exists" do
      let(:source) { "#{data_dir}/#{tag_file2}" }

      it 'updates attributes' do
        parent = FactoryBot.create(:classification, :name => "location", :description => "Location", :single_value => 1, :default => 1)
        FactoryBot.create(:classification_tag,      :name => "london",   :description => "London",   :parent => parent)

        expect do
          TaskHelpers::Imports::Tags.new.import(options)
        end.to_not output.to_stderr

        assert_test_tag_two_present
        expect(Tag.exists?(tag_two_cat)).to be_falsey
        expect(parent.find_entry_by_name('london').description).to eq('London Town')
        tag_cat = Classification.lookup_by_name(tag_two_name)
        expect(tag_cat.description).to eq(tag_two_desc)
      end
    end

    describe "when the source is an invalid tag file" do
      context "no category name or description" do
        let(:source) { "#{data_dir}/#{bad_tag_file1}" }
        it 'fails to import a tag file' do
          expect do
            TaskHelpers::Imports::Tags.new.import(options)
          end.to output.to_stderr
        end
      end

      context "invalid category attribute" do
        let(:source) { "#{data_dir}/#{bad_tag_file2}" }
        it 'fails to import a tag file' do
          expect do
            TaskHelpers::Imports::Tags.new.import(options)
          end.to output.to_stderr
        end
      end

      context "invalid entries" do
        let(:source) { "#{data_dir}/#{bad_tag_file3}" }
        it 'fails to import a tag file' do
          expect do
            TaskHelpers::Imports::Tags.new.import(options)
          end.to output.to_stderr
        end
      end
    end
  end

  def assert_test_tag_one_present
    tag_cat = Classification.lookup_by_name(tag_one_name)
    expect(tag_cat).to_not be_nil
    expect(tag_cat.tag).to_not be_nil
    expect(File.split(tag_cat.tag.name).last).to_not be_nil
    expect(tag_cat.default).to be_falsey
    expect(tag_cat.entries.count).to eq(2)
    expect(Tag.exists?(:name => tag_one_entry)).to be true
  end

  def assert_test_tag_two_present
    tag_cat = Classification.lookup_by_name(tag_two_name)
    expect(tag_cat).to_not be_nil
    expect(tag_cat.tag).to_not be_nil
    expect(File.split(tag_cat.tag.name).last).to_not be_nil
    expect(tag_cat.default).to be true
    expect(tag_cat.entries.count).to eq(6)
    expect(Tag.exists?(:name => tag_two_entry)).to be true
  end

  def assert_test_tag_category_count
    tag_cats = Classification.is_category
    expect(tag_cats.count).to eq(2)
  end
end
