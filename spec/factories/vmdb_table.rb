FactoryBot.define do
  factory :vmdb_table
  factory :vmdb_table_evm, :parent => :vmdb_table, :class => "VmdbTableEvm"
  factory :vmdb_table_text, :parent => :vmdb_table, :class => "VmdbTableText"
end
