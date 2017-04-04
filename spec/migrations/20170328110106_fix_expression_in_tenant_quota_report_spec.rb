require_migration

describe FixExpressionInTenantQuotaReport do
  let(:miq_report_stub) { migration_stub(:MiqReport) }
  let(:old_condition) do
    <<-EOS
      ---
      - !ruby/object:MiqExpression
          exp:
              ">":
              count: tenants.tenant_quotas
          value: 0
    EOS
  end

  let(:new_condition) do
    <<-EOS
      ---
      - !ruby/object:MiqExpression
          exp:
              ">":
              count: Tenant.tenant_quotas
          value: 0
    EOS
  end

  migration_context :up do
    it 'converts old format of field to current format' do
      miq_report = miq_report_stub.create!(:db => 'Tenant', :rpt_type => 'Custom', :conditions => old_condition)

      migrate

      expect(miq_report.reload.conditions).to eq(new_condition)
    end
  end

  migration_context :down do
    it 'converts current format of field to old format' do
      miq_report = miq_report_stub.create!(:db => 'Tenant', :rpt_type => 'Custom', :conditions => new_condition)

      migrate

      expect(miq_report.reload.conditions).to eq(old_condition)
    end
  end
end
