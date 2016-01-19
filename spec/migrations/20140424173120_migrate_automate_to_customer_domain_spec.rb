require_migration

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

        expect(miq_ae_namespace_stub.where(:name => '$').first).not_to be_nil

        domain = miq_ae_namespace_stub.where(:name => 'Customer').first
        expect(test_ns.parent_id).to eq(domain.id)
      end

      it 'with existing Customer namespace' do
        customer_ns = miq_ae_namespace_stub.create!(:name => 'Customer')
        test_ns     = miq_ae_namespace_stub.create!(:name => 'ns_test')

        migrate

        domain = miq_ae_namespace_stub.where(:name => 'Customer', :priority => 1).first

        test_ns.reload
        customer_ns.reload

        expect(test_ns.parent_id).to     eq(domain.id)
        expect(customer_ns.parent_id).to eq(domain.id)
      end

      it 'with existing domain' do
        miq_ae_namespace_stub.create!(:name => 'ManageIQ', :priority => 0)
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test')

        migrate

        domain = miq_ae_namespace_stub.where(:name => 'Customer', :priority => 1).first

        test_ns.reload

        expect(test_ns.parent_id).to eq(domain.id)
      end

      it 'with inherited class' do
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test')
        ae_class = miq_ae_class_stub.create!(:inherits => 'ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        expect(ae_class.inherits).to eq('Customer/ns_test/class1')
      end

      it 'with inherited class from another domain' do
        miq_ae_namespace_stub.create!(:name => 'domain2', :priority => 2)
        test_ns  = miq_ae_namespace_stub.create!(:name => 'ns_test')
        ae_class = miq_ae_class_stub.create!(:inherits => 'domain2/ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        expect(ae_class.inherits).to eq('domain2/ns_test/class1')
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

        expect(miq_ae_namespace_stub.where(:name => '$').first).not_to    be_nil
        expect(miq_ae_namespace_stub.where(:name => 'Customer').first).to be_nil

        test_ns.reload
        expect(test_ns.parent_id).to be_nil
      end

      it 'with existing Customer namespace' do
        domain      = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        customer_ns = miq_ae_namespace_stub.create!(:name => 'Customer', :parent_id => domain.id)
        test_ns     = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)

        migrate

        expect(miq_ae_namespace_stub.where(:name => 'Customer').first).not_to             be_nil
        expect(miq_ae_namespace_stub.where(:name => 'Customer', :priority => 1).first).to be_nil

        test_ns.reload
        customer_ns.reload

        expect(test_ns.parent_id).to     be_nil
        expect(customer_ns.parent_id).to be_nil
      end

      it 'with existing domain' do
        miq_ae_namespace_stub.create!(:name => 'ManageIQ', :priority => 0)
        domain     = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        test_ns    = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)

        migrate

        expect(miq_ae_namespace_stub.where(:name => 'Customer').first).to     be_nil
        expect(miq_ae_namespace_stub.where(:name => 'ManageIQ').first).not_to be_nil

        test_ns.reload
        expect(test_ns.parent_id).to be_nil
      end

      it 'with inherited class' do
        domain  = miq_ae_namespace_stub.create!(:name => 'Customer', :priority => 1)
        test_ns = miq_ae_namespace_stub.create!(:name => 'ns_test',  :parent_id => domain.id)
        ae_class = miq_ae_class_stub.create!(:inherits => 'Customer/ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        expect(ae_class.inherits).to eq('ns_test/class1')
      end

      it 'with inherited class from another domain' do
        miq_ae_namespace_stub.create!(:name => 'domain2', :priority => 2)
        test_ns  = miq_ae_namespace_stub.create!(:name => 'ns_test')
        ae_class = miq_ae_class_stub.create!(:inherits => 'domain2/ns_test/class1', :namespace_id => test_ns)

        migrate

        ae_class.reload
        expect(ae_class.inherits).to eq('domain2/ns_test/class1')
      end
    end
  end
end
