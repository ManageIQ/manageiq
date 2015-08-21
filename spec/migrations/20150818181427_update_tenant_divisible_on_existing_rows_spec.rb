require "spec_helper"
require Rails.root.join("db/migrate/20150818181427_update_tenant_divisible_on_existing_rows.rb")

describe UpdateTenantDivisibleOnExistingRows do
  let(:tenant)  { migration_stub(:Tenant) }

  migration_context :up do
    it "updates nil values to true" do
      t_nil = UpdateTenantDivisibleOnExistingRows::Tenant.create(:divisible => nil)
      t_nil.divisible.should be_nil

      migrate

      t_nil.reload
      t_nil.divisible.should be_true
    end

    it "leaves true and false values alone" do
      t_true  = UpdateTenantDivisibleOnExistingRows::Tenant.create(:divisible => true)
      t_false = UpdateTenantDivisibleOnExistingRows::Tenant.create(:divisible => false)

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
