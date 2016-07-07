require_migration

describe FixForemanProviderType do
  class FixForemanProviderType::Provider < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  migration_context :up do
    include_examples "column migration", :type, :Provider, described_class::NAME_MAP.first
  end

  migration_context :down do
    include_examples "column migration", :type, :Provider, described_class::NAME_MAP.invert.first
  end
end
