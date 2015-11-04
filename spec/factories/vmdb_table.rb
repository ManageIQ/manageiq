FactoryGirl.define do
  factory :vmdb_table do
  end

  factory :vmdb_table_evm, :parent => :vmdb_table, :class => "VmdbTableEvm" do
  end

  factory :vmdb_table_text, :parent => :vmdb_table, :class => "VmdbTableText" do
  end
end
