RSpec.describe Partition do
  it "#partition_type_name" do
    partition = FactoryBot.create(:partition)

    partition.partition_type = 999
    expect(partition.partition_type_name).to eq(Partition::UNKNOWN_PARTITION_TYPE)

    Partition::PARTITION_TYPE_NAMES.each do |partition_type, name|
      partition.partition_type = partition_type
      expect(partition.partition_type_name).to eq(name)
    end
  end
end
