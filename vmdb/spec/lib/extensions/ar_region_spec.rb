require "spec_helper"

describe "AR Regions extension" do
  before(:each) do
    ManageIQ::Providers::Vmware::InfraManager::Vm.stub(:rails_sequence_factor).and_return(10)
  end

  after(:each) do
    ManageIQ::Providers::Vmware::InfraManager::Vm.clear_region_cache
  end

  it ".id_to_region" do
    ManageIQ::Providers::Vmware::InfraManager::Vm.id_to_region(5).should == 0
    ManageIQ::Providers::Vmware::InfraManager::Vm.id_to_region(15).should == 1
    ManageIQ::Providers::Vmware::InfraManager::Vm.id_to_region(25).should == 2
  end

  it ".region_to_range" do
    ManageIQ::Providers::Vmware::InfraManager::Vm.region_to_range(0).should == (0..9)
    ManageIQ::Providers::Vmware::InfraManager::Vm.region_to_range(1).should == (10..19)
    ManageIQ::Providers::Vmware::InfraManager::Vm.region_to_range(2).should == (20..29)
  end

  it ".compressed_id?" do
    ManageIQ::Providers::Vmware::InfraManager::Vm.compressed_id?(5).should     be_false
    ManageIQ::Providers::Vmware::InfraManager::Vm.compressed_id?(15).should    be_false
    ManageIQ::Providers::Vmware::InfraManager::Vm.compressed_id?(25).should    be_false
    ManageIQ::Providers::Vmware::InfraManager::Vm.compressed_id?("5").should   be_false
    ManageIQ::Providers::Vmware::InfraManager::Vm.compressed_id?("1r5").should be_true
    ManageIQ::Providers::Vmware::InfraManager::Vm.compressed_id?("2r5").should be_true
  end

  it ".split_id" do
    ManageIQ::Providers::Vmware::InfraManager::Vm.split_id(5).should     == [0, 5]
    ManageIQ::Providers::Vmware::InfraManager::Vm.split_id(15).should    == [1, 5]
    ManageIQ::Providers::Vmware::InfraManager::Vm.split_id(25).should    == [2, 5]
    ManageIQ::Providers::Vmware::InfraManager::Vm.split_id("5").should   == [0, 5]
    ManageIQ::Providers::Vmware::InfraManager::Vm.split_id("1r5").should == [1, 5]
    ManageIQ::Providers::Vmware::InfraManager::Vm.split_id("2r5").should == [2, 5]
  end


  it ".compress_id" do
    ManageIQ::Providers::Vmware::InfraManager::Vm.compress_id(5).should  == "5"
    ManageIQ::Providers::Vmware::InfraManager::Vm.compress_id(15).should == "1r5"
    ManageIQ::Providers::Vmware::InfraManager::Vm.compress_id(25).should == "2r5"
  end

  it ".uncompress_id" do
    ManageIQ::Providers::Vmware::InfraManager::Vm.uncompress_id("5").should   == 5
    ManageIQ::Providers::Vmware::InfraManager::Vm.uncompress_id("1r5").should == 15
    ManageIQ::Providers::Vmware::InfraManager::Vm.uncompress_id("2r5").should == 25
  end

  context "with some records" do
    before(:each) do
      # Add dummy records until the ids line up with the @rails_sequence_factor
      loop do
        dummy = FactoryGirl.create(:vm_vmware)
        @base_id = dummy.id
        break if (@base_id % ManageIQ::Providers::Vmware::InfraManager::Vm.rails_sequence_factor) == 0
        dummy.destroy
      end

      @base_region = (@base_id / ManageIQ::Providers::Vmware::InfraManager::Vm.rails_sequence_factor)
      ManageIQ::Providers::Vmware::InfraManager::Vm.stub(:my_region_number).and_return(@base_region + 1)
      ManageIQ::Providers::Vmware::InfraManager::Vm.stub(:rails_sequence_start).and_return(ManageIQ::Providers::Vmware::InfraManager::Vm.my_region_number * ManageIQ::Providers::Vmware::InfraManager::Vm.rails_sequence_factor + @base_id)
      ManageIQ::Providers::Vmware::InfraManager::Vm.stub(:rails_sequence_end).and_return(ManageIQ::Providers::Vmware::InfraManager::Vm.rails_sequence_start + ManageIQ::Providers::Vmware::InfraManager::Vm.rails_sequence_factor - 1)

      29.times { FactoryGirl.create(:vm_vmware) } # 1 less because we created the base one above
    end

    it ".in_my_region" do
      recs = ManageIQ::Providers::Vmware::InfraManager::Vm.in_my_region
      recs.count.should == 10
      recs.all? { |v| v.region_number == ManageIQ::Providers::Vmware::InfraManager::Vm.my_region_number }.should be_true
    end

    context ".in_region" do
      it "with region param" do
        recs = ManageIQ::Providers::Vmware::InfraManager::Vm.in_region(@base_region)
        recs.count.should == 10
        recs.all? { |v| v.region_number == @base_region }.should be_true
      end

      it "with nil param" do
        recs = ManageIQ::Providers::Vmware::InfraManager::Vm.in_region(nil)
        recs.count.should == 30
      end
    end

    it ".with_region" do
      recs = ManageIQ::Providers::Vmware::InfraManager::Vm.with_region(@base_region) { ManageIQ::Providers::Vmware::InfraManager::Vm.all }
      recs.count.should == 10
      recs.all? { |v| v.region_number == @base_region }.should be_true
    end

    it "#region_id" do
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 5).region_id.should  == @base_region
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 9).region_id.should  == @base_region
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 15).region_id.should == @base_region + 1
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 19).region_id.should == @base_region + 1
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 25).region_id.should == @base_region + 2
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 29).region_id.should == @base_region + 2

      ManageIQ::Providers::Vmware::InfraManager::Vm.new.region_id.should == ManageIQ::Providers::Vmware::InfraManager::Vm.my_region_number
    end

    it "#compressed_id" do
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 5).compressed_id.should  == "#{@base_region}r5"
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 9).compressed_id.should  == "#{@base_region}r9"
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 15).compressed_id.should == "#{@base_region + 1}r5"
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 19).compressed_id.should == "#{@base_region + 1}r9"
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 25).compressed_id.should == "#{@base_region + 2}r5"
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 29).compressed_id.should == "#{@base_region + 2}r9"

      ManageIQ::Providers::Vmware::InfraManager::Vm.new.compressed_id.should be_nil
    end

    it "#split_id" do
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 5).split_id.should  == [@base_region, 5]
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 9).split_id.should  == [@base_region, 9]
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 15).split_id.should == [@base_region + 1, 5]
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 19).split_id.should == [@base_region + 1, 9]
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 25).split_id.should == [@base_region + 2, 5]
      ManageIQ::Providers::Vmware::InfraManager::Vm.find(@base_id + 29).split_id.should == [@base_region + 2, 9]

      ManageIQ::Providers::Vmware::InfraManager::Vm.new.split_id.should == [ManageIQ::Providers::Vmware::InfraManager::Vm.my_region_number, nil]
    end

  end
end
