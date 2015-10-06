require "spec_helper"
require_migration

describe UpdateTenantDivisibleOnExistingRows do
  let(:tenant_stub)  { migration_stub(:Tenant) }

  migration_context :up do
    it "updates nil values to true" do
      t_nil = tenant_stub.create!(:divisible => nil)
      t_nil.divisible.should be_nil

      migrate

      t_nil.reload
      t_nil.divisible.should be_true
    end

    it "leaves true and false values alone" do
      t_true  = tenant_stub.create!(:divisible => true)
      t_false = tenant_stub.create!(:divisible => false)

      t_true.divisible.should  be_true
      t_false.divisible.should be_false

      migrate

      t_true.reload
      t_false.reload

      t_true.divisible.should  be_true
      t_false.divisible.should be_false
    end
  end
end
