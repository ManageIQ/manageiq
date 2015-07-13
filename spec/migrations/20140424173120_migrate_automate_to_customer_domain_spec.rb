require 'spec_helper'
require Rails.root.join('db/migrate/20140424173120_migrate_automate_to_customer_domain.rb')

describe MigrateAutomateToCustomerDomain do
  let(:miq_ae_namespace_stub) { migration_stub(:MiqAeNamespace) }
  let(:miq_ae_class_stub)     { migration_stub(:MiqAeClass) }

  migration_context :up do
    before do
      migration_stub(:MiqAeNamespace).create!(:name => '$')
    end

    context 'migrates root namespace to customer domain' do
      it 'with a single namespace' do
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test')

        migrate

        test_ns.reload

        miq_ae_namespace_stub.where(:name => '$').first.should_not be_nil

        domain = miq_ae_namespace_stub.where(:name => 'Customer').first
        test_ns.parent_id.should eq(domain.id)
      end

      it 'with existing Customer namespace' do
        customer_ns = miq_ae_namespace_stub.create!(:name => 'Customer')
        test_ns     = miq_ae_namespace_stub.create!(:name => 'ns_test')

        migrate

        domain = miq_ae_namespace_stub.where(:name => 'Customer', :priority => 1).first

        test_ns.reload
        customer_ns.reload

        test_ns.parent_id.should     eq(domain.id)
        customer_ns.parent_id.should eq(domain.id)
      end

      it 'with existing domain' do
        miq_ae_namespace_stub.create!(:name => 'ManageIQ', :priority => 0)
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test')

        migrate

        domain = miq_ae_namespace_stub.where(:name => 'Customer', :priority => 1).first

        test_ns.reload

        test_ns.parent_id.should eq(domain.id)
      end

      it 'with inherited class' do
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test')
        ae_class = miq_ae_class_stub.create!(:inherits => 'ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        ae_class.inherits.should eq('Customer/ns_test/class1')
      end

      it 'with inherited class from another domain' do
        miq_ae_namespace_stub.create!(:name => 'domain2', :priority => 2)
        test_ns  = miq_ae_namespace_stub.create!(:name => 'ns_test')
        ae_class = miq_ae_class_stub.create!(:inherits => 'domain2/ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        ae_class.inherits.should eq('domain2/ns_test/class1')
      end
    end
  end

  migration_context :down do
    before do
      migration_stub(:MiqAeNamespace).create!(:name => '$')
    end

    context 'migrates customer domain to root namespaces' do
      it 'with a single namespace' do
        domain  = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)

        migrate

        miq_ae_namespace_stub.where(:name => '$').first.should_not    be_nil
        miq_ae_namespace_stub.where(:name => 'Customer').first.should be_nil

        test_ns.reload
        test_ns.parent_id.should be_nil
      end

      it 'with existing Customer namespace' do
        domain      = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        customer_ns = miq_ae_namespace_stub.create!(:name => 'Customer', :parent_id => domain.id)
        test_ns     = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)

        migrate

        miq_ae_namespace_stub.where(:name => 'Customer').first.should_not             be_nil
        miq_ae_namespace_stub.where(:name => 'Customer', :priority => 1).first.should be_nil

        test_ns.reload
        customer_ns.reload

        test_ns.parent_id.should     be_nil
        customer_ns.parent_id.should be_nil
      end

      it 'with existing domain' do
        miq_ae_namespace_stub.create!(:name => 'ManageIQ', :priority => 0)
        domain     = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        test_ns    = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)

        migrate

        miq_ae_namespace_stub.where(:name => 'Customer').first.should     be_nil
        miq_ae_namespace_stub.where(:name => 'ManageIQ').first.should_not be_nil

        test_ns.reload
        test_ns.parent_id.should be_nil
      end

      it 'with inherited class' do
        domain  = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)
        ae_class = miq_ae_class_stub.create!(:inherits => 'Customer/ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        ae_class.inherits.should eq('ns_test/class1')
      end

      it 'with inherited class from another domain' do
        miq_ae_namespace_stub.create!(:name => 'domain2', :priority => 2)
        test_ns  = miq_ae_namespace_stub.create!(:name => 'ns_test')
        ae_class = miq_ae_class_stub.create!(:inherits => 'domain2/ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        ae_class.inherits.should eq('domain2/ns_test/class1')
      end
    end
  end
end
