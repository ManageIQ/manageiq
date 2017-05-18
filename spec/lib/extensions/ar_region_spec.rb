describe "AR Regions extension" do
  let(:base_class) { ManageIQ::Providers::Vmware::InfraManager::Vm }

  before(:each) do
    allow(base_class).to receive(:rails_sequence_factor).and_return(10)
  end

  after(:each) do
    base_class.clear_region_cache
  end

  it ".id_to_region" do
    expect(base_class.id_to_region(5)).to eq(0)
    expect(base_class.id_to_region(15)).to eq(1)
    expect(base_class.id_to_region(25)).to eq(2)
  end

  it ".id_in_region" do
    expect(base_class.id_in_region(5, 0)).to eq(5)
    expect(base_class.id_in_region(5, 1)).to eq(15)
    expect(base_class.id_in_region(5, 2)).to eq(25)
  end

  it ".region_to_range" do
    expect(base_class.region_to_range(0)).to eq(0..9)
    expect(base_class.region_to_range(1)).to eq(10..19)
    expect(base_class.region_to_range(2)).to eq(20..29)
  end

  it ".compressed_id?" do
    expect(base_class.compressed_id?(5)).to        be_truthy
    expect(base_class.compressed_id?(15)).to       be_truthy
    expect(base_class.compressed_id?("5")).to      be_truthy
    expect(base_class.compressed_id?('100023')).to be_truthy
    expect(base_class.compressed_id?('1r23')).to   be_truthy
    expect(base_class.compressed_id?('10r10')).to  be_truthy
    expect(base_class.compressed_id?('hello')).to  be_falsey
    expect(base_class.compressed_id?('r1')).to     be_falsey
    expect(base_class.compressed_id?('1r')).to     be_falsey
    expect(base_class.compressed_id?('1rr1')).to   be_falsey
  end

  it ".split_id" do
    expect(base_class.split_id(5)).to eq([0, 5])
    expect(base_class.split_id(15)).to eq([1, 5])
    expect(base_class.split_id(25)).to eq([2, 5])
    expect(base_class.split_id("5")).to eq([0, 5])
    expect(base_class.split_id("1r5")).to eq([1, 5])
    expect(base_class.split_id("2r5")).to eq([2, 5])
  end

  it ".compress_id" do
    expect(base_class.compress_id(5)).to eq("5")
    expect(base_class.compress_id(15)).to eq("1r5")
    expect(base_class.compress_id(25)).to eq("2r5")
  end

  it ".uncompress_id" do
    expect(base_class.uncompress_id("5")).to eq(5)
    expect(base_class.uncompress_id("1r5")).to eq(15)
    expect(base_class.uncompress_id("2r5")).to eq(25)
  end

  describe ".group_ids_by_region" do
    it "works with integer ids" do
      one_region = [1, 2, 3, 4]
      expect(base_class.group_ids_by_region(one_region)).to eq(0 => [1, 2, 3, 4])
      multiple_regions = [1, 2, 991, 992]
      expect(base_class.group_ids_by_region(multiple_regions)).to eq(0 => [1, 2], 99 => [991, 992])
    end

    it "works with string ids" do
      one_region_string = %w(1 2 3 4)
      expect(base_class.group_ids_by_region(one_region_string)).to eq(0 => %w(1 2 3 4))
      multiple_regions_string = %w(1 2 991 992)
      expect(base_class.group_ids_by_region(multiple_regions_string)).to eq(0 => %w(1 2), 99 => %w(991 992))
    end
  end

  context "with some records" do
    before(:each) do
      # Add dummy records until the ids line up with the @rails_sequence_factor
      loop do
        dummy = FactoryGirl.create(:vm_vmware)
        @base_id = dummy.id
        @base_region, small_id = dummy.split_id
        break if small_id == 0
        dummy.destroy
      end

      allow(base_class).to receive(:my_region_number).and_return(@base_region + 1)

      29.times { FactoryGirl.create(:vm_vmware) } # 1 less because we created the base one above
    end

    it ".in_my_region" do
      recs = base_class.in_my_region
      expect(recs.count).to eq(10)
      expect(recs.all? { |v| v.region_number == base_class.my_region_number }).to be_truthy
    end

    context ".in_region" do
      it "with region param" do
        recs = base_class.in_region(@base_region)
        expect(recs.count).to eq(10)
        expect(recs.all? { |v| v.region_number == @base_region }).to be_truthy
      end

      it "with nil param" do
        recs = base_class.in_region(nil)
        expect(recs.count).to eq(30)
      end
    end

    it ".with_region" do
      recs = base_class.with_region(@base_region) { base_class.all }
      expect(recs.count).to eq(10)
      expect(recs.all? { |v| v.region_number == @base_region }).to be_truthy
    end

    it "#region_id" do
      expect(base_class.find(@base_id + 5).region_id).to eq(@base_region)
      expect(base_class.find(@base_id + 9).region_id).to eq(@base_region)
      expect(base_class.find(@base_id + 15).region_id).to eq(@base_region + 1)
      expect(base_class.find(@base_id + 19).region_id).to eq(@base_region + 1)
      expect(base_class.find(@base_id + 25).region_id).to eq(@base_region + 2)
      expect(base_class.find(@base_id + 29).region_id).to eq(@base_region + 2)

      expect(base_class.new.region_id).to eq(base_class.my_region_number)
      expect(base_class.new(:id => @base_id + 29).region_id).to eq(@base_region + 2)
    end

    it "#compressed_id" do
      expect(base_class.find(@base_id + 5).compressed_id).to eq("#{@base_region}r5")
      expect(base_class.find(@base_id + 9).compressed_id).to eq("#{@base_region}r9")
      expect(base_class.find(@base_id + 15).compressed_id).to eq("#{@base_region + 1}r5")
      expect(base_class.find(@base_id + 19).compressed_id).to eq("#{@base_region + 1}r9")
      expect(base_class.find(@base_id + 25).compressed_id).to eq("#{@base_region + 2}r5")
      expect(base_class.find(@base_id + 29).compressed_id).to eq("#{@base_region + 2}r9")

      expect(base_class.new.compressed_id).to be_nil
    end

    it "#split_id" do
      expect(base_class.find(@base_id + 5).split_id).to eq([@base_region, 5])
      expect(base_class.find(@base_id + 9).split_id).to eq([@base_region, 9])
      expect(base_class.find(@base_id + 15).split_id).to eq([@base_region + 1, 5])
      expect(base_class.find(@base_id + 19).split_id).to eq([@base_region + 1, 9])
      expect(base_class.find(@base_id + 25).split_id).to eq([@base_region + 2, 5])
      expect(base_class.find(@base_id + 29).split_id).to eq([@base_region + 2, 9])

      expect(base_class.new.split_id).to eq([base_class.my_region_number, nil])
    end
  end

  describe ".my_region_number" do
    it "reads region from the environment" do
      reject_db_sequence_lookup
      allow(ENV).to receive(:fetch).with("REGION", nil).and_return("23")
      allow(File).to receive(:exist?).with(/REGION/).and_return(false)
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      expect(VmOrTemplate.my_region_number).to eq(23)
    end

    it "reads region from the REGION file" do
      reject_db_sequence_lookup
      allow(ENV).to receive(:fetch).with("REGION", nil).and_return(nil)
      expect(File).to receive(:exist?).with(/REGION/).and_return(true)
      expect(File).to receive(:read).with(/REGION/).and_return("33")
      expect(VmOrTemplate.my_region_number).to eq(33)
    end

    it "reads region from the database" do
      db_sequence_lookup(44)
      allow(ENV).to receive(:fetch).with("REGION", nil).and_return(nil)
      allow(File).to receive(:exist?).with(/REGION/).and_return(false)
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      expect(VmOrTemplate.my_region_number).to eq(44)
    end

    it "falls back to region 0" do
      reject_db_sequence_lookup
      allow(ENV).to receive(:fetch).with("REGION", nil).and_return(nil)
      allow(File).to receive(:exist?).with(/REGION/).and_return(false)
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      expect(VmOrTemplate.my_region_number).to eq(0)
    end

    it "Uses REGION file over all others" do
      db_sequence_lookup(44)
      allow(ENV).to receive(:fetch).with("REGION", nil).and_return("23")
      allow(File).to receive(:exist?).with(/REGION/).and_return(true)
      allow(File).to receive(:read).with(/REGION/).and_return("33")
      expect(VmOrTemplate.my_region_number).to eq(33)
    end

    def reject_db_sequence_lookup
      allow(VmOrTemplate.connection).to receive(:data_source_exists?)
        .at_least(:once).with("miq_databases").and_return(false)
    end

    def db_sequence_lookup(sequence = nil)
      allow(VmOrTemplate.connection).to receive(:data_source_exists?)
        .at_least(:once).with("miq_databases").and_return(true)
      allow(VmOrTemplate.connection).to receive(:select_value)
        .at_least(:once).with("SELECT last_value FROM miq_databases_id_seq")
        .and_return(ArRegion::DEFAULT_RAILS_SEQUENCE_FACTOR * sequence + 1)
    end
  end
end
