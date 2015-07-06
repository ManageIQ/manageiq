require "spec_helper"
require Rails.root.join("db/migrate/20100622195644_add_start_address_to_partitions.rb")


describe AddStartAddressToPartitions do
  migration_context :up do
    let(:partition_stub) { migration_stub(:Partition) }

    it "extracts the start_address from the reserved column" do
      start_address_bigint = 9223372036854775807
      reserved = {:start_address => start_address_bigint, :another_field => "another value"}
      partition = partition_stub.create!(:reserved => reserved)

      migrate

      reserved.delete :start_address
      partition.reload.start_address.should eq start_address_bigint
      partition.reserved.should eq reserved
    end

    it "leaves the reserved column null when it only contains start_address" do
      start_address_bigint = 9223372036854775807
      reserved = {:start_address => start_address_bigint}
      partition = partition_stub.create!(:reserved => reserved)

      migrate

      partition.reload.start_address.should eq start_address_bigint
      partition.reserved.should be_nil
    end
  end

  migration_context :down do
    let(:partition_stub) { migration_stub(:Partition) }

    it "stores the start_address in the reserved column" do
      start_address = 9223372036854775807
      partition = partition_stub.create!(:start_address => start_address, :reserved => nil)

      migrate

      reserved = {:start_address => start_address}
      partition.reload.reserved.should eq reserved
    end
  end
end
