require "spec_helper"

describe "AR Regions extension" do
  before(:each) do
    VmVmware.stub(:rails_sequence_factor).and_return(10)
  end

  after(:each) do
    VmVmware.clear_region_cache
  end

  it ".id_to_region" do
    VmVmware.id_to_region(5).should == 0
    VmVmware.id_to_region(15).should == 1
    VmVmware.id_to_region(25).should == 2
  end

  it ".region_to_range" do
    VmVmware.region_to_range(0).should == (0..9)
    VmVmware.region_to_range(1).should == (10..19)
    VmVmware.region_to_range(2).should == (20..29)
  end

  it ".compressed_id?" do
    VmVmware.compressed_id?(5).should     be_false
    VmVmware.compressed_id?(15).should    be_false
    VmVmware.compressed_id?(25).should    be_false
    VmVmware.compressed_id?("5").should   be_false
    VmVmware.compressed_id?("1r5").should be_true
    VmVmware.compressed_id?("2r5").should be_true
  end

  it ".split_id" do
    VmVmware.split_id(5).should     == [0, 5]
    VmVmware.split_id(15).should    == [1, 5]
    VmVmware.split_id(25).should    == [2, 5]
    VmVmware.split_id("5").should   == [0, 5]
    VmVmware.split_id("1r5").should == [1, 5]
    VmVmware.split_id("2r5").should == [2, 5]
  end


  it ".compress_id" do
    VmVmware.compress_id(5).should  == "5"
    VmVmware.compress_id(15).should == "1r5"
    VmVmware.compress_id(25).should == "2r5"
  end

  it ".uncompress_id" do
    VmVmware.uncompress_id("5").should   == 5
    VmVmware.uncompress_id("1r5").should == 15
    VmVmware.uncompress_id("2r5").should == 25
  end

  context "with some records" do
    before(:each) do
      # Add dummy records until the ids line up with the @rails_sequence_factor
      loop do
        dummy = FactoryGirl.create(:vm_vmware)
        @base_id = dummy.id
        break if (@base_id % VmVmware.rails_sequence_factor) == 0
        dummy.destroy
      end

      @base_region = (@base_id / VmVmware.rails_sequence_factor)
      VmVmware.stub(:my_region_number).and_return(@base_region + 1)
      VmVmware.stub(:rails_sequence_start).and_return(VmVmware.my_region_number * VmVmware.rails_sequence_factor + @base_id)
      VmVmware.stub(:rails_sequence_end).and_return(VmVmware.rails_sequence_start + VmVmware.rails_sequence_factor - 1)

      29.times { FactoryGirl.create(:vm_vmware) } # 1 less because we created the base one above
    end

    it ".in_my_region" do
      recs = VmVmware.in_my_region.all
      recs.count.should == 10
      recs.all? { |v| v.region_number == VmVmware.my_region_number }.should be_true
    end

    context ".in_region" do
      it "with region param" do
        recs = VmVmware.in_region(@base_region).all
        recs.count.should == 10
        recs.all? { |v| v.region_number == @base_region }.should be_true
      end

      it "with nil param" do
        recs = VmVmware.in_region(nil)
        recs.count.should == 30
      end
    end

    it ".with_region" do
      recs = VmVmware.with_region(@base_region) { VmVmware.all }
      recs.count.should == 10
      recs.all? { |v| v.region_number == @base_region }.should be_true
    end

    it "#region_id" do
      VmVmware.find(@base_id + 5).region_id.should  == @base_region
      VmVmware.find(@base_id + 9).region_id.should  == @base_region
      VmVmware.find(@base_id + 15).region_id.should == @base_region + 1
      VmVmware.find(@base_id + 19).region_id.should == @base_region + 1
      VmVmware.find(@base_id + 25).region_id.should == @base_region + 2
      VmVmware.find(@base_id + 29).region_id.should == @base_region + 2

      VmVmware.new.region_id.should == VmVmware.my_region_number
    end

    it "#compressed_id" do
      VmVmware.find(@base_id + 5).compressed_id.should  == "#{@base_region}r5"
      VmVmware.find(@base_id + 9).compressed_id.should  == "#{@base_region}r9"
      VmVmware.find(@base_id + 15).compressed_id.should == "#{@base_region + 1}r5"
      VmVmware.find(@base_id + 19).compressed_id.should == "#{@base_region + 1}r9"
      VmVmware.find(@base_id + 25).compressed_id.should == "#{@base_region + 2}r5"
      VmVmware.find(@base_id + 29).compressed_id.should == "#{@base_region + 2}r9"

      VmVmware.new.compressed_id.should be_nil
    end

    it "#split_id" do
      VmVmware.find(@base_id + 5).split_id.should  == [@base_region, 5]
      VmVmware.find(@base_id + 9).split_id.should  == [@base_region, 9]
      VmVmware.find(@base_id + 15).split_id.should == [@base_region + 1, 5]
      VmVmware.find(@base_id + 19).split_id.should == [@base_region + 1, 9]
      VmVmware.find(@base_id + 25).split_id.should == [@base_region + 2, 5]
      VmVmware.find(@base_id + 29).split_id.should == [@base_region + 2, 9]

      VmVmware.new.split_id.should == [VmVmware.my_region_number, nil]
    end

  end
end
