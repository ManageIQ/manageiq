require "spec_helper"

describe Partition do
  it "#partition_type_name" do
    partition = FactoryGirl.create(:partition)

    partition.partition_type = 999
    partition.partition_type_name.should == Partition::UNKNOWN_PARTITION_TYPE

    Partition::PARTITION_TYPE_NAMES.each do |partition_type, name|
      partition.partition_type = partition_type
      partition.partition_type_name.should == name
    end

  end
end
