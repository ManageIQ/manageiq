class FixExpressionInTenantQuotaReport < ActiveRecord::Migration[5.0]
  class MiqReport < ActiveRecord::Base
    def self.with_tenant_custom_report_and_condition(value)
      where(:db => 'Tenant', :rpt_type => 'Custom').where("conditions LIKE ?", "%#{value}%")
    end
  end

  OLD_VALUE = 'count: tenants.tenant_quotas'.freeze
  NEW_VALUE = 'count: Tenant.tenant_quotas'.freeze

  def up
    MiqReport.with_tenant_custom_report_and_condition(OLD_VALUE).each do |x|
      x.conditions.gsub!(OLD_VALUE, NEW_VALUE)
      x.save
    end
  end

  def down
    MiqReport.with_tenant_custom_report_and_condition(NEW_VALUE).each do |x|
      x.conditions.gsub!(NEW_VALUE, OLD_VALUE)
      x.save
    end
  end
end
