class MigrateAutomateToCustomerDomain < ActiveRecord::Migration
  class MiqAeNamespace < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI

    def self.root_instances
      where(:parent_id => nil).where(arel_table[:name].not_eq("$"))
    end

    def self.all_domains
      root_instances.where(arel_table[:priority].not_eq(nil))
    end

    def self.root_namespaces
      root_instances.where(:priority => nil)
    end
  end

  class MiqAeClass < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  CUSTOMER_DOMAIN = "Customer"

  def up
    say_with_time("Migrate Automate root namespaces to Customer domain") do

      if MiqAeNamespace.root_namespaces.count > 0
        domain = MiqAeNamespace.create!(:name => CUSTOMER_DOMAIN, :priority => 1, :enabled => true, :updated_by => "system")
        MiqAeNamespace.root_namespaces.update_all(:parent_id => domain.id)

        migrate_miq_ae_class
      end
    end
  end

  def down
    say_with_time("Migrate Automate Customer domain namespaces to root namespaces") do
      domain = MiqAeNamespace.all_domains.where(:name => CUSTOMER_DOMAIN).first
      if domain
        MiqAeNamespace.where(:parent_id => domain.id).update_all(:parent_id => nil)

        revert_miq_ae_class
        domain.destroy
      end
    end
  end

  def inherited_miq_ae_classes(&block)
    MiqAeClass.where(MiqAeClass.arel_table[:inherits].not_eq(nil)).where("inherits NOT LIKE '$/%'")
  end

  def migrate_miq_ae_class
    domain_names = MiqAeNamespace.all_domains.where(MiqAeNamespace.arel_table[:name].not_eq("Customer")).pluck(:name)

    inherited_miq_ae_classes.each do |ae_class|
      next if domain_names.include?(ae_class.inherits.split("/").first)
      ae_class.update_attributes(:inherits => File.join(CUSTOMER_DOMAIN, ae_class.inherits))
    end
  end

  def revert_miq_ae_class
    inherited_miq_ae_classes.each do |ae_class|
      if ae_class.inherits.starts_with?("#{CUSTOMER_DOMAIN}/")
        ae_class.update_attributes(:inherits => ae_class.inherits.sub("#{CUSTOMER_DOMAIN}/", ''))
      end
    end
  end
end
