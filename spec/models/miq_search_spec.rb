RSpec.describe MiqSearch do
  context "validate name uniqueness" do
    it "with same name" do
      miq_search = FactoryBot.create(:miq_search)

      expect { FactoryBot.create(:miq_search, :name => miq_search.name) }
        .to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end

    it "with different names" do
      FactoryBot.create(:miq_search)

      expect { FactoryBot.create(:miq_search) }.to_not raise_error
    end
  end

  context "validate description uniqueness" do
    it "with same description" do
      miq_search = FactoryBot.create(:miq_search, :search_type => 'global')

      expect { FactoryBot.create(:miq_search, :description => miq_search.description, :search_type => 'global') }
        .to raise_error(ActiveRecord::RecordInvalid, /Description has already been taken/)
    end

    it "with different descriptions" do
      FactoryBot.create(:miq_search, :search_type => 'global')

      expect { FactoryBot.create(:miq_search, :search_type => 'global') }.to_not raise_error
    end
  end

  describe '#descriptions' do
    it "hashes" do
      srchs = [
        FactoryBot.create(:miq_search, :description => 'a'),
        FactoryBot.create(:miq_search, :description => 'b'),
        FactoryBot.create(:miq_search, :description => 'c')
      ]

      expect(MiqSearch.descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description,
        srchs[2].id.to_s => srchs[2].description)
    end

    it "supports scopes" do
      srchs = [
        FactoryBot.create(:miq_search, :description => 'a', :db => 'Vm'),
        FactoryBot.create(:miq_search, :description => 'b', :db => 'Vm'),
        FactoryBot.create(:miq_search, :description => 'c', :db => 'Host')
      ]

      expect(MiqSearch.where(:db => 'Vm').descriptions).to eq(
        srchs[0].id.to_s => srchs[0].description,
        srchs[1].id.to_s => srchs[1].description)
    end
  end

  let(:vm_location_search) do
    FactoryBot.create(:miq_search,
                       :db     => "Vm",
                       :filter => MiqExpression.new("=" => {"field" => "Vm-location", "value" => "good"})
                      )
  end

  let(:matched_vms) { FactoryBot.create_list(:vm_vmware, 2, :location => "good") }
  let(:other_vms)   { FactoryBot.create_list(:vm_vmware, 1, :location => "other") }
  let(:all_vms)     { matched_vms + other_vms }
  let(:partial_matched_vms) { [matched_vms.first] }
  let(:partial_vms) { partial_matched_vms + other_vms }

  describe "#quick_search?" do
    let(:qs) { MiqExpression.new("=" => {"field" => "Vm-name", "value" => :user_input}) }
    it "supports no filter" do
      expect(FactoryBot.build(:miq_search, :filter => nil)).not_to be_quick_search
    end

    it "supports a filter" do
      expect(vm_location_search).not_to be_quick_search
    end

    it "supports a quick search" do
      expect(FactoryBot.build(:miq_search, :filter => qs)).to be_quick_search
    end
  end

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:miq_search)
    expect { m.valid? }.not_to make_database_queries
  end

  describe "#results" do
    it "respects filter" do
      all_vms
      expect(vm_location_search.results).to match_array(matched_vms)
    end
  end

  describe "#filtered" do
    it "works with models" do
      all_vms
      expect(vm_location_search.filtered(Vm)).to match_array(matched_vms)
    end

    it "works with scopes" do
      all_vms
      expect(vm_location_search.filtered(Vm.all)).to match_array(matched_vms)
    end

    it "finds elements only in the array" do
      all_vms
      expect(vm_location_search.filtered(partial_vms)).to match_array(partial_matched_vms)
    end

    it "brings back empty array for empty arrays" do
      all_vms
      expect(vm_location_search.filtered([])).to match_array([])
    end
  end

  describe ".filtered" do
    it "uses an existing search" do
      all_vms
      results = MiqSearch.filtered(vm_location_search.id, "Vm", partial_vms)
      expect(results).to match_array(partial_matched_vms)
    end

    it "calls Rbac directly for no search" do
      all_vms
      results = MiqSearch.filtered(0, "Vm", partial_vms)
      expect(results).to match_array(partial_vms)
    end
  end

  describe "#destroy" do
    let(:search) { FactoryBot.create(:miq_search) }

    it "destroys search if miq_schedule does not use it" do
      expect { search.destroy! }.not_to raise_error
    end

    it "does not destroy search if it referenced in at least one miq_schedule" do
      schedules = double
      allow(search).to receive(:miq_schedules).and_return(schedules)
      allow(schedules).to receive(:empty?).and_return(false)

      expect { expect { search.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed) }.to_not(change { MiqSearch.count })
      expect(search.errors[:base][0]).to eq("Search is referenced in a schedule and cannot be deleted")
    end
  end

  # This test is intentionally long winded instead of breaking it up into
  # multiple tests per concern because of how long a full seed may take.
  describe ".seed" do
    let(:tmpdir)        { Pathname.new(Dir.mktmpdir) }
    let(:fixture_dir)   { tmpdir.join("db/fixtures") }
    let(:search_yml)    { fixture_dir.join("miq_searches.yml") }

    before do
      FileUtils.mkdir_p(fixture_dir)
      FileUtils.cp_r(Rails.root.join('db', 'fixtures', 'miq_searches.yml'), search_yml)
      stub_const("MiqSearch::FIXTURE_DIR", fixture_dir)
      described_class.seed
    end

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "seeds miq_search table from db/fixtures/miq_search.yml and keeps custom searches" do
      yml = YAML.load_file(search_yml)

      # check if all supplied default searches were loaded
      expect(MiqSearch.count).to eq(yml.size)

      # check if custom searches were not removed
      custom_search = "some search"
      FactoryBot.create(:miq_search, :name => custom_search)
      described_class.seed
      expect(MiqSearch.count).to eq(yml.size + 1)
      expect(MiqSearch.where(:name => custom_search)).to exist

      # check that default search removed from DB if name-db of that search was not present in miq_search_yml
      old_name = yml[0]["attributes"]["name"]
      db = yml[0]["attributes"]["db"]
      new_name = "default_Absolutely New Name"
      yml[0]["attributes"]["name"] = new_name
      File.write(search_yml, yml.to_yaml)
      described_class.seed
      expect(MiqSearch.count).to eq(yml.size + 1)
      expect(MiqSearch.where(:name => new_name, :db => db)).to exist
      expect(MiqSearch.where(:name => old_name, :db => db)).to be_empty
    end
  end
end
