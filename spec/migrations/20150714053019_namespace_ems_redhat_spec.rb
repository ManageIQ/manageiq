require_migration

describe NamespaceEmsRedhat do
  class NamespaceEmsRedhat::ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  migration_context :up do
    include_examples "column migration", :type, :ExtManagementSystem, described_class::NAME_MAP.first
  end

  migration_context :down do
    include_examples "column migration", :type, :ExtManagementSystem, described_class::NAME_MAP.invert.first
  end
end
