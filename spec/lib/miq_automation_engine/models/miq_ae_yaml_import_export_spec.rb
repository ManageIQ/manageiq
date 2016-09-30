describe MiqAeDatastore do
  before do
    @additional_columns = {'on_error'    => "call great gazoo",
                           'on_entry'    => "call fred flintstone",
                           'on_exit'     => "call barney rubble",
                           'max_retries' => "10",
                           'collect'     => "dinosaurs",
                           'max_time'    => "100"}
    @clear_default_password = 'little_secret'
    @clear_password = 'secret'
    @relations_value = "bedrock relations"
    @domain_counts = {'dom' => 1, 'ns' => 3, 'class' => 4, 'inst' => 10,
                             'meth' => 3, 'field' => 12, 'value' => 8}
    @domain_counts_with_extra_items = {'dom' => 1, 'ns' => 4, 'class' => 5, 'inst' => 11,
                             'meth' => 3, 'field' => 12, 'value' => 8}
    EvmSpecHelper.local_miq_server
    @tenant = Tenant.seed
    create_factory_data("manageiq", 0, MiqAeDomain::SYSTEM_SOURCE)
    setup_export_dir
    set_manageiq_values
  end

  context "yaml export" do
    it "non existing domain" do
      expect { export_model("UNKNOWN") }.to raise_error(MiqAeException::DomainNotFound)
    end

    it "child namespace as domain" do
      expect { export_model(@aen1.fqname) }.to raise_error(MiqAeException::DomainNotFound)
    end

    it "non existing namespace" do
      options = {'namespace' => 'UNKNOWN'}
      options['export_dir'] = @export_dir
      expect { export_model(@manageiq_domain.name, options) }
        .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "non existing class" do
      options = {'namespace' => @aen1.name, 'class' => 'UNKNOWN'}
      options['export_dir'] = @export_dir
      expect { export_model(@manageiq_domain.name, options) }
        .to raise_error(MiqAeException::ClassNotFound)
    end

    it "missing domain yaml file should raise exception" do
      options = {'overwrite' => true, 'export_dir' => @export_dir}
      export_model(@manageiq_domain.name, options)
      FileUtils.rm Dir.glob("#{@export_dir}/**/__domain__.yaml"), :force => true
      expect { reset_and_import(@export_dir, @manageiq_domain.name) }
        .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "invalid zip file should raise exception" do
      create_bogus_zip_file
      export_options = {'zip_file' => @zip_file}
      expect { reset_and_import(@export_dir, @manageiq_domain.name, export_options) }
        .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "invalid yaml file should raise exception" do
      create_bogus_yaml_file
      export_options = {'yaml_file' => @yaml_file}
      expect { reset_and_import(@export_dir, @manageiq_domain.name, export_options) }
        .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "an existing directory should raise exception" do
      FileUtils.mkdir_p(File.join(@export_dir, @manageiq_domain.name))
      expect { export_model(@manageiq_domain.name) }.to raise_error(MiqAeException::DirectoryExists)
    end

    it "an existing zip file should raise exception" do
      File.open(@zip_file, 'w') { |f| f.write("dummy domain data") }
      options = {'zip_file' => @zip_file}
      expect { export_model(@manageiq_domain.name, options) }
        .to raise_error(MiqAeException::FileExists)
      expect(File.exist?(@zip_file)).to be_truthy
    end

    it "an existing yaml file should raise exception" do
      create_bogus_yaml_file
      options = {'yaml_file' => @yaml_file}
      expect { export_model(@manageiq_domain.name, options) }
        .to raise_error(MiqAeException::FileExists)
      expect(File.exist?(@yaml_file)).to be_truthy
    end

    it "an existing directory with overwrite should not raise exception" do
      FileUtils.mkdir_p(File.join(@export_dir, @manageiq_domain.name))
      export_options = {'export_dir' => @export_dir, 'overwrite' => true}
      assert_existing_exported_model(export_options, {})
    end

    it "an existing zip file with overwrite should not raise exception" do
      File.open(@zip_file, 'w') { |f| f.write("dummy domain data") }
      export_options = {'zip_file' => @zip_file, 'overwrite' => true}
      import_options = {'zip_file' => @zip_file}
      assert_existing_exported_model(export_options, import_options)
    end

    it "an existing yaml file with overwrite should not raise exception" do
      File.open(@yaml_file, 'w') { |f| f.write("dummy domain data") }
      export_options = {'yaml_file' => @yaml_file, 'overwrite' => true}
      import_options = {'yaml_file' => @yaml_file}
      assert_existing_exported_model(export_options, import_options)
    end

    def assert_existing_exported_model(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts(@domain_counts)
    end
  end

  context "yaml import" do
    it "an existing domain from zip should fail" do
      export_options = {'zip_file' => @zip_file}
      import_options = {'zip_file' => @zip_file, 'import_as' => 'ManageIQ'}
      assert_existing_domain_fails(export_options, import_options)
    end

    it "an existing domain from yaml should fail" do
      export_options = {'yaml_file' => @yaml_file}
      import_options = {'yaml_file' => @yaml_file, 'import_as' => 'ManageIQ'}
      assert_existing_domain_fails(export_options, import_options)
    end

    it "an existing domain from directory should fail" do
      import_options = {'import_dir' => @export_dir, 'import_as' => 'ManageIQ'}
      assert_existing_domain_fails({}, import_options)
    end

    it "a non existing folder should fail" do
      import_options = {'import_dir' => "no_such_folder", 'preview' => true, 'mode' => 'add'}
      expect { MiqAeImport.new("fred", import_options).import }
        .to raise_error(MiqAeException::DirectoryNotFound)
    end

    it "a non existing zip file should fail" do
      import_options = {'zip_file' => "missing_zip_file", 'preview' => true, 'mode' => 'add'}
      assert_import_failure_with_missing_file(import_options)
    end

    it "a non existing yaml file should fail" do
      import_options = {'yaml_file' => "missing_yaml_file", 'preview' => true, 'mode' => 'add'}
      assert_import_failure_with_missing_file(import_options)
    end

    def assert_existing_domain_fails(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      expect { reset_and_import(@export_dir, @manageiq_domain.name, import_options) }
        .to raise_error(MiqAeException::InvalidDomain)
    end

    def assert_import_failure_with_missing_file(import_options)
      expect { MiqAeImport.new("fred", import_options).import }
        .to raise_error(MiqAeException::FileNotFound)
    end
  end

  context "tenant id" do
    it "validate export data" do
      export_model(@manageiq_domain.name)
      domain_file = File.join(@export_dir, @manageiq_domain.name, '__domain__.yaml')
      data = YAML.load_file(domain_file)
      expect(data.fetch_path('object', 'attributes', 'tenant_id')).to eq(@tenant.id)
    end

    it "namespace should not contain tenant id" do
      export_model(@manageiq_domain.name)
      namespace_file = File.join(@export_dir, @manageiq_domain.name, @aen1.name, '__namespace__.yaml')
      data = YAML.load_file(namespace_file)
      hash = data.fetch_path('object', 'attributes')
      expect(hash.key?('tenant_id')).to be_falsey
    end
  end

  context "domain_only_attributes" do
    it "namespace should not contain domain only attributes" do
      domain_only_attrs = %w(source top_level_namespace)
      export_model(@manageiq_domain.name)
      namespace_file = File.join(@export_dir, @manageiq_domain.name, @aen1.name, '__namespace__.yaml')
      data = YAML.load_file(namespace_file)
      hash = data.fetch_path('object', 'attributes')
      domain_only_attrs.each do |attr|
        expect(hash.key?(attr)).to be_falsey
      end
    end
  end

  context "export import roundtrip" do
    context "export all domains" do
      before do
        create_factory_data("customer", 1, MiqAeDomain::USER_SOURCE)
        set_customer_values
      end

      it "import all domains, from directory" do
        assert_all_domains_imported({}, {})
      end

      it "import all domains, from zip" do
        options = {'zip_file' => @zip_file}
        assert_all_domains_imported(options, options)
      end

      it "import all domains, from yaml" do
        options = {'yaml_file' => @yaml_file}
        assert_all_domains_imported(options, options)
      end

      def assert_all_domains_imported(export_options, import_options)
        export_model(MiqAeYamlImportExportMixin::ALL_DOMAINS, export_options)
        reset_and_import(@export_dir, MiqAeYamlImportExportMixin::ALL_DOMAINS, import_options)
        check_counts('dom'  => 2, 'ns'    => 6,  'class' => 8, 'inst'  => 20,
                     'meth' => 6, 'field' => 24, 'value' => 16)
      end

      it "import single domain, from directory" do
        assert_single_domain_import({}, {})
      end

      it "import single domain, from zip" do
        options = {'zip_file' => @zip_file}
        assert_single_domain_import(options, options)
      end

      it "import single domain, from yaml" do
        options = {'yaml_file' => @yaml_file}
        assert_single_domain_import(options, options)
      end

      it "import single domain, from yaml, no overwrite" do
        options = {'yaml_file' => @yaml_file}
        assert_single_domain_import(options, options)

        add_extra_items_to_customer_domain
        check_counts(@domain_counts_with_extra_items)

        import(@export_dir, @customer_domain.name, options)
        check_counts(@domain_counts_with_extra_items)
      end

      it "import single domain, from yaml, overwrite" do
        options = {'yaml_file' => @yaml_file, 'overwrite' => true}
        assert_single_domain_import(options, options)

        add_extra_items_to_customer_domain
        check_counts(@domain_counts_with_extra_items)

        import(@export_dir, @customer_domain.name, options)
        check_counts(@domain_counts)
      end

      def add_extra_items_to_customer_domain
        @customer_domain = MiqAeDomain.find_by_name("customer")
        n    = FactoryGirl.create(:miq_ae_namespace, :name => "bonus_namespace_2", :parent_id => @customer_domain.id)
        n_c1 = FactoryGirl.create(:miq_ae_class, :name => "bonus_test_class_3", :namespace_id => n.id)
        FactoryGirl.create(:miq_ae_instance, :name => "bonus_test_instance1", :class_id => n_c1.id)
      end

      it "import single user domain" do
        options = {'yaml_file' => @yaml_file}
        assert_single_domain_import(options, options)
        dom = MiqAeDomain.find_by_fqname(@customer_domain.name, false)
        expect(dom).not_to be_enabled
      end

      it "import single system domain" do
        options = {'yaml_file' => @yaml_file}
        @customer_domain.update_attributes(:source => MiqAeDomain::SYSTEM_SOURCE)
        assert_single_domain_import(options, options)
        dom = MiqAeDomain.find_by_fqname(@customer_domain.name, false)
        expect(dom).to be_enabled
      end

      def assert_single_domain_import(export_options, import_options)
        export_model(MiqAeYamlImportExportMixin::ALL_DOMAINS, export_options)
        reset_and_import(@export_dir, @customer_domain.name, import_options)
        check_counts(@domain_counts)
      end
    end

    it "domain, check password field is not in clear text" do
      export_model(@manageiq_domain.name)
      data = YAML.load_file(@instance_file)
      password_field_hash = data.fetch_path('object', 'fields').detect { |h| h.keys[0] == 'password_field' }
      expect(password_field_hash.fetch_path('password_field', 'value')).to eq(MiqAePassword.encrypt(@clear_password))
    end

    it "domain, check default password field is not in clear text" do
      export_model(@manageiq_domain.name)
      data = YAML.load_file(@class_file)
      password_field_hash = data.fetch_path('object', 'schema').detect { |h| h['field']['name'] == 'default_password_field' }
      expect(password_field_hash.fetch_path('field', 'default_value')).to eq(MiqAePassword.encrypt(@clear_default_password))
    end

    it "domain, as directory" do
      import_options = {'import_dir' => @export_dir, 'enabled' => true}
      assert_export_import_roundtrip({}, import_options)
    end

    it "domain, as zip" do
      options = {'zip_file' => @zip_file, 'enabled' => true}
      assert_export_import_roundtrip(options, options)
    end

    it "domain, as yaml" do
      options = {'yaml_file' => @yaml_file, 'enabled' => true}
      assert_export_import_roundtrip(options, options)
    end

    def assert_export_import_roundtrip(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts(@domain_counts)
      dom = MiqAeDomain.find_by_fqname(@manageiq_domain.name, false)
      expect(dom.source).to eq(MiqAeDomain::SYSTEM_SOURCE)
      expect(dom).to be_enabled
    end

    it "domain, priority 0 should get retained for manageiq domain" do
      export_model(@manageiq_domain.name)
      expect(@manageiq_domain.priority).to equal(0)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts(@domain_counts)

      ns = MiqAeNamespace.find_by_fqname(@manageiq_domain.name, false)
      expect(ns.priority).to equal(0)
    end

    it "domain, using import_as (new domain name), to directory" do
      import_options = {'import_as' => 'fred', 'import_dir' => @export_dir}
      assert_import_as({}, import_options)
    end

    it "domain, using import_as (new domain name), as zip" do
      export_options = {'zip_file' => @zip_file}
      import_options = {'zip_file' => @zip_file, 'import_as' => 'fred'}
      assert_import_as(export_options, import_options)
    end

    it "domain, using import_as (new domain name), as yaml" do
      export_options = {'yaml_file' => @yaml_file}
      import_options = {'yaml_file' => @yaml_file, 'import_as' => 'fred'}
      assert_import_as(export_options, import_options)
    end

    def assert_import_as(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 2, 'ns'    => 6,  'class' => 8,  'inst'  => 20,
                   'meth' => 6, 'field' => 24, 'value' => 16)
      expect(MiqAeDomain.find_by_fqname(import_options['import_as'])).not_to be_nil
    end

    it "domain, using export_as (new domain name), to directory" do
      export_options = {'export_dir' => @export_dir, 'export_as' => @export_as}
      assert_export_as(export_options, {})
    end

    it "domain, using export_as (new domain name), as zip" do
      export_options = {'zip_file' => @zip_file, 'export_as' => @export_as}
      import_options = {'zip_file' => @zip_file}
      assert_export_as(export_options, import_options)
    end

    it "domain, using export_as (new domain name), as yaml" do
      export_options = {'yaml_file' => @yaml_file, 'export_as' => @export_as}
      import_options = {'yaml_file' => @yaml_file}
      assert_export_as(export_options, import_options)
    end

    def assert_export_as(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @export_as, import_options)
      check_counts(@domain_counts)
      expect(MiqAeDomain.find_by_fqname(@export_as)).not_to be_nil
    end

    it "domain, import only namespace, to directory" do
      import_options = {'namespace' => @aen1.name, 'import_dir' => @export_dir}
      assert_import_namespace_only({}, import_options)
    end

    it "domain, import only namespace, to zip" do
      export_options = {'zip_file' => @zip_file}
      import_options = {'namespace' => @aen1.name, 'zip_file' => @zip_file}
      assert_import_namespace_only(export_options, import_options)
    end

    it "domain, import only namespace, to yaml" do
      export_options = {'yaml_file' => @yaml_file}
      import_options = {'namespace' => @aen1.name, 'yaml_file' => @yaml_file}
      assert_import_namespace_only(export_options, import_options)
    end

    def assert_import_namespace_only(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 2, 'class' => 3, 'inst'  => 6,
                   'meth' => 2, 'field' => 6, 'value' => 4)
    end

    it "domain, import only multi-part namespace, to directory" do
      import_options = {'namespace' => @aen1_1.fqname_sans_domain, 'import_dir' => @export_dir}
      assert_import_multipart_namespace_only({}, import_options)
    end

    it "domain, import only multi-part namespace, to zip" do
      import_options = {'namespace' => @aen1_1.fqname_sans_domain, 'zip_file' => @zip_file}
      export_options = {'zip_file' => @zip_file}
      assert_import_multipart_namespace_only(export_options, import_options)
    end

    it "domain, import only multi-part namespace, to yaml" do
      import_options = {'namespace' => @aen1_1.fqname_sans_domain, 'yaml_file' => @yaml_file}
      export_options = {'yaml_file' => @yaml_file}
      assert_import_multipart_namespace_only(export_options, import_options)
    end

    def assert_import_multipart_namespace_only(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 2, 'class' => 1, 'inst'  => 1,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end

    it "domain, import only class, to directory" do
      import_options = {'import_dir' => @export_dir, 'namespace' => @aen1.name,
                        'class_name' => @aen1_aec1.name}
      assert_import_class_only({}, import_options)
    end

    it "domain, import only class, to zip" do
      export_options = {'zip_file' => @zip_file}
      import_options = {'zip_file' => @zip_file, 'namespace' => @aen1.name,
                        'class_name' => @aen1_aec1.name}
      assert_import_class_only(export_options, import_options)
    end

    it "domain, import only class, to yaml" do
      export_options = {'yaml_file' => @yaml_file}
      import_options = {'yaml_file'  => @yaml_file, 'namespace' => @aen1.name,
                        'class_name' => @aen1_aec1.name}
      assert_import_class_only(export_options, import_options)
    end

    def assert_import_class_only(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1,  'ns'    => 1, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 6, 'value' => 4)
    end

    it "namespace, to directory" do
      export_options = {'namespace' => @aen1.name, 'export_dir' => @export_dir}
      import_options = {'import_dir' => @export_dir}
      assert_single_namespace_export(export_options, import_options)
    end

    it "namespace, as zip" do
      export_options = {'namespace' => @aen1.name, 'zip_file' => @zip_file}
      import_options = {'zip_file' => @zip_file}
      assert_single_namespace_export(export_options, import_options)
    end

    it "namespace, as yaml" do
      export_options = {'namespace' => @aen1.name, 'yaml_file' => @yaml_file}
      import_options = {'yaml_file' => @yaml_file}
      assert_single_namespace_export(export_options, import_options)
    end

    def assert_single_namespace_export(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 2, 'class' => 3, 'inst'  => 6,
                   'meth' => 2, 'field' => 6, 'value' => 4)
    end

    it "namespace, multi-part, to directory" do
      export_options = {'namespace' => @aen1_1.fqname_sans_domain, 'export_dir' => @export_dir}
      assert_multi_namespace_export(export_options, {})
    end

    it "namespace, multi-part, as zip" do
      export_options = {'namespace' => @aen1_1.fqname_sans_domain, 'zip_file' => @zip_file}
      import_options = {'zip_file' => @zip_file}
      assert_multi_namespace_export(export_options, import_options)
    end

    it "namespace, multi-part, as yaml" do
      export_options = {'namespace' => @aen1_1.fqname_sans_domain, 'yaml_file' => @yaml_file}
      import_options = {'yaml_file' => @yaml_file}
      assert_multi_namespace_export(export_options, import_options)
    end

    def assert_multi_namespace_export(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 2, 'class' => 1, 'inst'  => 1,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end

    it "class, with methods, add new instance, export, then import using mode=replace" do
      options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      options['export_dir'] = @export_dir
      export_model(@manageiq_domain.name, options)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('dom'  => 1, 'ns'    => 1, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 6, 'value' => 4)
      @manageiq_domain = MiqAeNamespace.find_by_fqname('manageiq', false)
      @aen1_aec1       = MiqAeClass.find_by_name('manageiq_test_class_1')
      @aen1_aec1_aei2  = FactoryGirl.create(:miq_ae_instance,
                                            :name     => 'test_instance3',
                                            :class_id => @aen1_aec1.id)
      setup_export_dir
      export_model(@manageiq_domain.name, options)
      MiqAeImport.new(@manageiq_domain.name, 'preview' => false, 'import_dir' => @export_dir).import
      check_counts('dom'  => 1, 'ns'    => 1, 'class' => 1, 'inst'  => 3,
                   'meth' => 2, 'field' => 6, 'value' => 4)
    end

    it "class, with methods, to directory" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_options['export_dir'] = @export_dir
      assert_class_with_methods_export(export_options, {})
    end

    it "class, with methods, as zip" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_options['zip_file'] = @zip_file
      import_options = {'zip_file' => @zip_file}
      assert_class_with_methods_export(export_options, import_options)
    end

    it "class, with methods, as yaml" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_options['yaml_file'] = @yaml_file
      import_options = {'yaml_file' => @yaml_file}
      assert_class_with_methods_export(export_options, import_options)
    end

    def assert_class_with_methods_export(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 1, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 6, 'value' => 4)
    end

    it "class, with builtin methods, as directory" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_options['export_dir'] = @export_dir
      assert_class_with_builtin_methods_export(export_options, {})
    end

    it "class, with builtin methods, as zip" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_options['zip_file'] = @zip_file
      import_options = {'zip_file' => @zip_file}
      assert_class_with_builtin_methods_export(export_options, import_options)
    end

    it "class, with builtin methods, as yaml" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_options['yaml_file'] = @yaml_file
      import_options = {'yaml_file' => @yaml_file}
      assert_class_with_builtin_methods_export(export_options, import_options)
    end

    def assert_class_with_builtin_methods_export(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 1, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 6, 'value' => 4)
      aen1_aec1  = MiqAeClass.find_by_name('manageiq_test_class_1')
      builtin_method = MiqAeMethod.find_by_class_id_and_name(aen1_aec1.id, 'test2')
      expect(builtin_method.location).to eql 'builtin'
      expect(builtin_method.data).to be_nil
    end

    it "class, without methods, to directory" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec2.name}
      export_options['export_dir'] = @export_dir
      assert_class_without_methods(export_options, {})
    end

    it "class, without methods, as zip" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec2.name}
      export_options['zip_file'] = @zip_file
      import_options = {'zip_file' => @zip_file}
      assert_class_without_methods(export_options, import_options)
    end

    it "class, without methods, as yaml" do
      export_options = {'namespace' => @aen1.name, 'class' => @aen1_aec2.name}
      export_options['yaml_file'] = @yaml_file
      import_options = {'yaml_file' => @yaml_file}
      assert_class_without_methods(export_options, import_options)
    end

    def assert_class_without_methods(export_options, import_options)
      export_model(@manageiq_domain.name, export_options)
      reset_and_import(@export_dir, @manageiq_domain.name, import_options)
      check_counts('dom'  => 1, 'ns'    => 1, 'class' => 1, 'inst'  => 3,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end
  end

  context 'backup and restore' do
    before do
      create_factory_data('customer', 16, MiqAeDomain::USER_SOURCE)
      set_customer_values
    end

    it 'all domains' do
      import_options = {'zip_file' => @zip_file, 'restore' => true}
      export_options = {'zip_file' => @zip_file}
      @customer_domain.update_attributes(:enabled => true)
      export_model(MiqAeYamlImportExportMixin::ALL_DOMAINS, export_options)
      reset_and_import(@export_dir, MiqAeYamlImportExportMixin::ALL_DOMAINS, import_options)
      expect(MiqAeDomain.find_by_fqname(@manageiq_domain.name, false).priority).to eql(0)
      cust_domain = MiqAeDomain.find_by_fqname(@customer_domain.name, false)
      expect(cust_domain.priority).to eql(1)
      expect(cust_domain).to be_enabled
      expect(MiqAeNamespace.find_by_fqname('$', false)).not_to be_nil
    end
  end

  def import(import_dir, domain, options = {})
    options = {'import_dir' => import_dir} if options.empty?
    import_options = {'preview' => false,
                      'tenant'  => @tenant,
                      'mode'    => 'add'}.merge(options)
    MiqAeImport.new(domain, import_options).import
  end

  def reset_and_import(import_dir, domain, options = {})
    options = {'import_dir' => import_dir} if options.empty?
    import_as = options['import_as'].presence
    if import_as.blank?
      MiqAeDatastore.reset
      [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| expect(k.count).to eq(0) }
    end
    import_options = {'preview' => true,
                      'tenant'  => @tenant,
                      'mode'    => 'add'}.merge(options)
    MiqAeImport.new(domain, import_options).import

    if import_as.blank?
      [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| expect(k.count).to eq(0) }
    end
    import_options['preview'] = false
    MiqAeImport.new(domain, import_options).import
  end

  def export_model(domain, export_options = {})
    export_options['export_dir'] = @export_dir if export_options.empty?
    MiqAeExport.new(domain, export_options).export
  end

  def create_field(class_obj, instance_obj, method_obj, options)
    if method_obj.nil?
      field = FactoryGirl.create(:miq_ae_field,
                                 :class_id      => class_obj.id,
                                 :name          => options['name'],
                                 :aetype        => options['type'],
                                 :datatype      => options['datatype'],
                                 :priority      => 1,
                                 :substitute    => true,
                                 :default_value => options['default_value'])
      create_field_value(instance_obj, field, options) unless options['value'].nil?
    else
      FactoryGirl.create(:miq_ae_field,
                         :method_id     => method_obj.id,
                         :name          => options['name'],
                         :aetype        => options['type'],
                         :datatype      => options['datatype'],
                         :priority      => 1,
                         :substitute    => true,
                         :default_value => options['value'])
    end
  end

  def create_field_value(instance_obj, field_obj, options)
    hash = {:instance_id => instance_obj.id,
            :field_id    => field_obj.id,
            :value       => options['value']}
    hash.reverse_merge!(@additional_columns) if options['type'] == 'relationship'

    FactoryGirl.create(:miq_ae_value, hash)
  end

  def create_fields(class_obj, instance_obj, method_obj)
    create_field(class_obj, instance_obj, nil,
                 'name'          => 'test_field1',
                 'type'          => 'attribute',
                 'datatype'      => 'string',
                 'default_value' => 'test_attribute_value',
                 'value'         => 'test_attribute_value')
    create_field(class_obj, instance_obj, nil,
                 'name'          => 'test_field2',
                 'type'          => 'relationship',
                 'datatype'      => 'string',
                 'default_value' => 'test_relationship_value',
                 'value'         => @relations_value)
    create_field(class_obj, instance_obj, nil,
                 'name'          => 'test_field3',
                 'type'          => 'relationship',
                 'datatype'      => 'string',
                 'default_value' => 'test_relationship_value',
                 'value'         => 'test_relationship_value')
    create_field(class_obj, instance_obj, nil,
                 'name'          => 'password_field',
                 'type'          => 'attribute',
                 'datatype'      => 'password',
                 'default_value' => 'test_relationship_value',
                 'value'         => @clear_password)
    create_field(class_obj, instance_obj, nil,
                 'name'          => 'default_password_field',
                 'type'          => 'attribute',
                 'datatype'      => 'password',
                 'default_value' => @clear_default_password,
                 'value'         => nil)
    create_field(class_obj, instance_obj, method_obj,
                 'name'          => 'test_method_input',
                 'type'          => 'attribute',
                 'datatype'      => 'string',
                 'default_value' => 'test_input_value',
                 'value'         => 'test_input_value')
  end

  def create_factory_data(domain_name, priority, source = MiqAeDomain::USER_SOURCE)
    domain   = FactoryGirl.create(:miq_ae_domain_enabled, :name => domain_name, :source => source, :priority => priority)
    n1       = FactoryGirl.create(:miq_ae_namespace, :name => "#{domain_name}_namespace_1",    :parent_id => domain.id)
    n1_c1    = FactoryGirl.create(:miq_ae_class,     :name => "#{domain_name}_test_class_1",   :namespace_id => n1.id)
    n1_1     = FactoryGirl.create(:miq_ae_namespace, :name => "#{domain_name}_namespace_1_1",  :parent_id => n1.id)
    n1_1_c1  = FactoryGirl.create(:miq_ae_class,     :name => "#{domain_name}_test_class_4",   :namespace_id => n1_1.id)
    n1_c1_i1 = FactoryGirl.create(:miq_ae_instance,  :name => "#{domain_name}_test_instance1", :class_id => n1_c1.id)
    n1_c1_m1 = FactoryGirl.create(:miq_ae_method,
                                  :class_id => n1_c1.id,
                                  :name     => 'test1',
                                  :scope    => "instance",
                                  :language => "ruby",
                                  # Method with no data
                                  :location => "inline")
    FactoryGirl.create(:miq_ae_instance,  :name => "#{domain_name}_test_instance1", :class_id => n1_1_c1.id)
    FactoryGirl.create(:miq_ae_method,
                       :class_id => n1_c1.id,
                       :name     => 'test2',
                       :scope    => "instance",
                       :language => "ruby",
                       :location => "builtin")
    FactoryGirl.create(:miq_ae_instance,  :name => 'test_instance2', :class_id => n1_c1.id)
    create_fields(n1_c1, n1_c1_i1, n1_c1_m1)

    n1_c2     = FactoryGirl.create(:miq_ae_class,     :name => "#{domain_name}_test_class_2",   :namespace_id => n1.id)
    3.times {   FactoryGirl.create(:miq_ae_instance,  :class_id => n1_c2.id) }
    n2        = FactoryGirl.create(:miq_ae_namespace, :name => "#{domain_name}_namespace_2",    :parent_id => domain.id)
    n2_c1     = FactoryGirl.create(:miq_ae_class,     :name => "#{domain_name}_test_class_3",   :namespace_id => n2.id)
    n2_c1_i1  = FactoryGirl.create(:miq_ae_instance,  :name => "#{domain_name}_test_instance1", :class_id => n2_c1.id)
    3.times {   FactoryGirl.create(:miq_ae_instance,  :class_id => n2_c1.id) }
    n2_c1_m1 =  FactoryGirl.create(:miq_ae_method,
                                   :class_id => n2_c1.id,
                                   :name     => 'namespace2_method_test1',
                                   :scope    => "instance",
                                   :language => "ruby",
                                   :data     => "puts 1",
                                   :location => "inline")
    create_fields(n2_c1, n2_c1_i1, n2_c1_m1)
  end

  def set_manageiq_values
    @manageiq_domain = MiqAeDomain.find_by_name("manageiq")
    @aen1            = MiqAeNamespace.find_by_name('manageiq_namespace_1')
    @aen1_1          = MiqAeNamespace.find_by_name('manageiq_namespace_1_1')
    @aen1_aec1       = MiqAeClass.find_by_name('manageiq_test_class_1')
    @aen1_aec2       = MiqAeClass.find_by_name('manageiq_test_class_2')
    @class_dir       = "#{@aen1_aec1.fqname}.class"
    @class_file      = File.join(@export_dir, @class_dir, '__class__.yaml')
    @instance_file   = File.join(@export_dir, @class_dir, 'manageiq_test_instance1.yaml')
    @class_name      = @aen1_aec1.name
  end

  def set_customer_values
    @customer_domain    = MiqAeDomain.find_by_name("customer")
    @customer_aen1      = MiqAeNamespace.find_by_name('customer_namespace_1')
    @customer_aen1_1    = MiqAeNamespace.find_by_name('customer_namespace_1_1')
    @customer_aen1_aec1 = MiqAeClass.find_by_name('customer_test_class_1')
    @customer_aen1_aec2 = MiqAeClass.find_by_name('customer_test_class_2')
    @class_name         = @customer_aen1_aec1.name
  end

  def setup_export_dir
    @export_dir = File.join(Dir.tmpdir, "rspec_export_tests")
    @export_as  = "manageiq" * 2
    @zip_file   = File.join(Dir.tmpdir, "yaml_model.zip")
    @yaml_file  = File.join(Dir.tmpdir, "yaml_model.yml")
    FileUtils.rm_rf(@export_dir) if File.exist?(@export_dir)
    FileUtils.rm_rf(@zip_file)   if File.exist?(@zip_file)
    FileUtils.rm_rf(@yaml_file)  if File.exist?(@yaml_file)
  end

  def check_counts(counts)
    expect(MiqAeDomain.count).to eql(counts['dom'])    if counts.key?('dom')
    ns_count = 0
    MiqAeDomain.all.each do |d|
      d.ae_namespaces.each { |ns| ns_count += child_namespace_count(ns) }
    end
    expect(ns_count).to eql(counts['ns'])    if counts.key?('ns')
    expect(MiqAeClass.count).to eql(counts['class']) if counts.key?('class')
    check_class_component_counts counts
    validate_additional_columns
  end

  def child_namespace_count(ns)
    count = 1
    ns.ae_namespaces.each { |n| count += child_namespace_count(n) }
    count
  end

  def validate_additional_columns
    klass = MiqAeClass.find_by_name(@class_name)
    return unless klass
    klass.ae_instances.each do |inst|
      inst.ae_values.select { |v| v.value == @relations_value }.each do |rel|
        validate_relation(rel.attributes)
      end
    end
  end

  def validate_relation(rel)
    @additional_columns.each { |k, v| expect(v).to eql(rel[k]) }
  end

  def check_class_component_counts(counts)
    expect(MiqAeInstance.count).to eql(counts['inst'])  if counts.key?('inst')
    expect(MiqAeMethod.count).to eql(counts['meth'])  if counts.key?('meth')
    expect(MiqAeField.count).to eql(counts['field']) if counts.key?('field')
    expect(MiqAeValue.count).to eql(counts['value']) if counts.key?('value')
  end

  def create_bogus_zip_file
    require 'zip/zipfilesystem'
    Zip::ZipFile.open(@zip_file, Zip::ZipFile::CREATE) do |zh|
      zh.file.open("first.txt", "w") { |f| f.puts "Hello world" }
      zh.dir.mkdir("mydir")
      zh.file.open("mydir/second.txt", "w") { |f| f.puts "Hello again" }
    end
  end

  def create_bogus_yaml_file
    open(@yaml_file, 'w') do |fd|
      a = {'A' => 1, 'B' => '2', 'C' => 3}
      fd.write(a.to_yaml)
    end
  end
end
