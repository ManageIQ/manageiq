require "spec_helper"
include MiqAeYamlImportExportMixin

describe MiqAeDatastore do

  before do
    @additional_columns = {'on_error'    => "call great gazoo",
                           'on_entry'    => "call fred flintstone",
                           'on_exit'     => "call barney rubble",
                           'max_retries' => "10",
                           'collect'     => "dinosaurs",
                           'max_time'    => "100"}

    @relations_value = "bedrock relations"
    create_factory_data("manageiq", 0)
    set_manageiq_values
    setup_export_dir
  end

  context "yaml export" do
    it "non existing domain" do
      expect { export_model("UNKNOWN") }.to raise_error(MiqAeException::DomainNotFound)
    end

    it "child namespace as domain" do
      expect { export_model(@aen1.fqname) }.to raise_error(MiqAeException::InvalidDomain)
    end

    it "non existing namespace" do
      expect { export_model(@manageiq_domain.name, false, 'namespace' => "UNKNOWN") }
      .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "non existing class" do
      options = {'namespace' => @aen1.name, 'class' => 'UNKNOWN'}
      expect { export_model(@manageiq_domain.name, false, options) }
      .to raise_error(MiqAeException::ClassNotFound)
    end

    it "missing domain yaml file should raise exception" do
      export_model(@manageiq_domain.name, false, 'overwrite' => true)
      FileUtils.rm Dir.glob("#{@export_dir}/**/__domain__.yaml"), :force => true
      expect { reset_and_import(@export_dir, @manageiq_domain.name) }
      .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "invalid zip file should raise exception" do
      create_bogus_zip_file
      reset_options = {}
      expect { reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true) }
      .to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "an existing file should raise exception" do
      File.open(@zip_file, 'w') { |f| f.write("dummy domain data") }
      expect { export_model(@manageiq_domain.name, true) }
      .to raise_error(MiqAeException::FileExists)
      File.exist?(@zip_file).should be_true
    end

    it "an existing file with overwrite should not raise exception" do
      File.open(@zip_file, 'w') { |f| f.write("dummy domain data") }
      export_model(@manageiq_domain.name, true, 'overwrite' => true)
      File.exist?(@zip_file).should be_true
    end

    it "an existing directory should raise exception" do
      FileUtils.mkdir_p(File.join(@export_dir, @manageiq_domain.name))
      expect { export_model(@manageiq_domain.name) }.to raise_error(MiqAeException::DirectoryExists)
    end

    it "an existing directory with overwrite should not raise exception" do
      FileUtils.mkdir_p(File.join(@export_dir, @manageiq_domain.name))
      export_model(@manageiq_domain.name, false, 'overwrite' => true)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                   'meth' => 3, 'field' => 8, 'value' => 6)
    end
  end

  context "yaml import" do
    it "an existing domain from zip should fail" do
      export_model(@manageiq_domain.name, true)
      File.exist?(@zip_file).should be_true
      reset_options = {'import_as' => 'Manageiq'}
      expect { reset_and_import(@export_dir, @manageiq_domain.name, reset_options,  true) }
      .to raise_error(MiqAeException::InvalidDomain)
    end

    it "an existing domain from directory should fail" do
      export_model(@manageiq_domain.name)
      reset_options = {'import_as' => 'Manageiq'}
      expect { reset_and_import(@export_dir, @manageiq_domain.name, reset_options) }
      .to raise_error(MiqAeException::InvalidDomain)
    end

    it "a non existing folder should fail" do
      import_options = {'import_dir' => "no_such_folder", 'preview' => true, 'mode' => 'add'}
      expect { MiqAeImport.new("fred", import_options).import }
      .to raise_error(MiqAeException::DirectoryNotFound)
    end

    it "a non existing zip file should fail" do
      import_options = {'zip_file' => "missing_zip_file", 'preview' => true, 'mode' => 'add'}
      expect { MiqAeImport.new("fred", import_options).import }
      .to raise_error(MiqAeException::FileNotFound)
    end
  end

  context "export import roundtrip" do

    context "export all domains" do
      before do
        create_factory_data("customer", 1)
        set_customer_values
      end

      it "import all domains, from directory" do
        export_model(ALL_DOMAINS)
        reset_and_import(@export_dir, ALL_DOMAINS)
        check_counts('ns'   => 8, 'class' => 8, 'inst'  => 20,
                     'meth' => 6, 'field' => 16, 'value' => 12)
      end

      it "import all domains, from zip" do
        export_model(ALL_DOMAINS, true)
        File.exist?(@zip_file).should be_true
        reset_options = {}
        reset_and_import(@export_dir, ALL_DOMAINS, reset_options, true)
        check_counts('ns'   => 8, 'class' => 8, 'inst'  => 20,
                     'meth' => 6, 'field' => 16, 'value' => 12)
      end

      it "import single domain, from directory" do
        export_model(ALL_DOMAINS)
        reset_and_import(@export_dir, @customer_domain.name)
        check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                     'meth' => 3, 'field' => 8, 'value' => 6)
      end

      it "import single domain, from zip" do
        export_model(ALL_DOMAINS, true)
        reset_options = {}
        puts "importing domain: #{@customer_domain.name}"
        reset_and_import(@export_dir, @customer_domain.name, reset_options, true)
        check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                     'meth' => 3, 'field' => 8, 'value' => 6)
      end
    end

    it "domain, as directory" do
      export_model(@manageiq_domain.name)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                   'meth' => 3, 'field' => 8, 'value' => 6)
    end

    it "domain, as zip" do
      export_model(@manageiq_domain.name, true)
      File.exist?(@zip_file).should be_true
      reset_options = {}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                   'meth' => 3, 'field' => 8, 'value' => 6)
    end

    it "domain, priority 0 should change priority to 1" do
      export_model(@manageiq_domain.name)
      @manageiq_domain.priority.should equal(0)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                   'meth' => 3, 'field' => 8, 'value' => 6)

      ns = MiqAeNamespace.find_by_name(@manageiq_domain.name)
      ns.priority.should equal(1)
    end

    it "domain, using import_as (new domain name), to directory" do
      export_model(@manageiq_domain.name)
      reset_options = {'import_as' => 'fred'}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options)
      check_counts('ns'   => 8, 'class' => 8,  'inst'  => 20,
                   'meth' => 6, 'field' => 16, 'value' => 12)
    end

    it "domain, using import_as (new domain name), as zip" do
      export_model(@manageiq_domain.name, true)
      File.exist?(@zip_file).should be_true
      reset_options = {'import_as' => 'fred'}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 8, 'class' => 8,  'inst'  => 20,
                   'meth' => 6, 'field' => 16, 'value' => 12)
    end

    it "domain, using export_as (new domain name), to directory" do
      options = {'export_as' => @export_as}
      export_model(@manageiq_domain.name, false, options)
      Dir.exist?(File.join(@export_dir, @export_as)).should be_true
      reset_options = {}
      reset_and_import(@export_dir, @export_as, reset_options, false)
      check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                   'meth' => 3, 'field' => 8, 'value' => 6)
      MiqAeDomain.all.include?(@export_as)
    end

    it "domain, using export_as (new domain name), as zip" do
      options = {'export_as' => @export_as}
      export_model(@manageiq_domain.name, true, options)
      File.exist?(@zip_file).should be_true
      reset_options = {}
      reset_and_import(@export_dir, @export_as, reset_options, true)
      check_counts('ns'   => 4, 'class' => 4, 'inst'  => 10,
                   'meth' => 3, 'field' => 8, 'value' => 6)
      MiqAeDomain.all.include?(@export_as)
    end

    it "domain, import only namespace, to directory" do
      export_model(@manageiq_domain.name)
      reset_options = {'namespace' => @aen1.name}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options)
      check_counts('ns'   => 3, 'class' => 3, 'inst'  => 6,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "domain, import only multi-part namespace, to directory" do
      export_model(@manageiq_domain.name)
      reset_options = {'namespace' => @aen1_1.ns_fqname}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options)
      check_counts('ns'   => 3, 'class' => 1, 'inst'  => 1,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end

    it "domain, import only class, to directory" do
      export_model(@manageiq_domain.name)
      reset_options = {'namespace' => @aen1.name, 'class_name' => @aen1_aec1.name}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "namespace, to directory" do
      options = {'namespace' => @aen1.name}
      export_model(@manageiq_domain.name, false, options)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 3, 'class' => 3, 'inst'  => 6,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "namespace, as zip" do
      options = {'namespace' => @aen1.name}
      export_model(@manageiq_domain.name, true, options)
      reset_options = {}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 3, 'class' => 3, 'inst'  => 6,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "namespace, multi-part, to directory" do
      options = {'namespace' => @aen1_1.ns_fqname}
      export_model(@manageiq_domain.name, false, options)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 3, 'class' => 1, 'inst'  => 1,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end

    it "namespace, multi-part, as zip" do
      options = {'namespace' => @aen1_1.ns_fqname}
      export_model(@manageiq_domain.name, true, options)
      reset_options = {}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 3, 'class' => 1, 'inst'  => 1,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end

    it "class, with methods, add new instance, export, then import using mode=replace" do
      options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_model(@manageiq_domain.name, false, options)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 4, 'value' => 3)
      @aen1_aec1_aei2   = FactoryGirl.create(:miq_ae_instance,  :name => 'test_instance2', :class_id => @aen1_aec1.id)

      setup_export_dir
      export_model(@manageiq_domain.name, false, options)
      MiqAeImport.new(@manageiq_domain.name, 'preview' => false, 'import_dir' => @export_dir).import
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 3,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "class, with methods, to directory" do
      options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_model(@manageiq_domain.name, false, options)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "class, with builtin methods, as zip" do
      inline_method = @aen1_aec1.ae_methods.first
      inline_method.location.should eql 'inline'
      inline_method.data.should_not be_nil
      inline_method.update_attributes('location' => 'builtin', 'data' => nil)

      options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_model(@manageiq_domain.name, true, options)
      reset_options = {}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 4, 'value' => 3)
      aen1_aec1  = MiqAeClass.find_by_name('manageiq_test_class_1')
      builtin_method = aen1_aec1.ae_methods.first
      builtin_method.location.should eql 'builtin'
      builtin_method.data.should be_nil
    end

    it "class, with methods, as zip" do
      options = {'namespace' => @aen1.name, 'class' => @aen1_aec1.name}
      export_model(@manageiq_domain.name, true, options)
      reset_options = {}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 2,
                   'meth' => 2, 'field' => 4, 'value' => 3)
    end

    it "class, without methods, to directory" do
      options = {'namespace' => @aen1.name, 'class' => @aen1_aec2.name}
      export_model(@manageiq_domain.name, false, options)
      reset_and_import(@export_dir, @manageiq_domain.name)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 3,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end

    it "class, without methods, as zip" do
      options = {'namespace' => @aen1.name, 'class' => @aen1_aec2.name}
      export_model(@manageiq_domain.name, true, options)
      reset_options = {}
      reset_and_import(@export_dir, @manageiq_domain.name, reset_options, true)
      check_counts('ns'   => 2, 'class' => 1, 'inst'  => 3,
                   'meth' => 0, 'field' => 0, 'value' => 0)
    end
  end

  def reset_and_import(import_dir, domain, options = {}, read_zip = false)
    import_as = options['import_as'].presence
    if import_as.blank?
      MiqAeDatastore.reset
      [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }
    end
    import_options = {'preview'    => true,
                      'mode'       => 'add',
                      'namespace'  => options['namespace'],
                      'class_name' => options['class_name']}
    read_zip ? import_options['zip_file'] = @zip_file : import_options['import_dir'] = import_dir
    import_options['import_as'] = import_as unless import_as.blank?
    MiqAeImport.new(domain, import_options).import

    if import_as.blank?
      [MiqAeClass, MiqAeField, MiqAeInstance, MiqAeNamespace, MiqAeMethod, MiqAeValue].each { |k| k.count.should == 0 }
    end
    import_options['preview'] = false
    MiqAeImport.new(domain, import_options).import
  end

  def export_model(domain, zipit = false, options = {})
    export_options = zipit ? {'zip_file' => @zip_file} : {'export_dir' => @export_dir}
    export_options['class'] = options['class'] if options['class'].present?
    export_options['namespace'] = options['namespace'] if options['namespace'].present?
    export_options['overwrite'] = options['overwrite'] if options['overwrite'].present?
    export_options['export_as'] = options['export_as'] if options['export_as'].present?
    MiqAeExport.new(domain, export_options).export
  end

  def create_field(class_obj, instance_obj, method_obj, options)
    if method_obj.nil?
      field = FactoryGirl.create(:miq_ae_field,
                                 :class_id   => class_obj.id,
                                 :name       => options['name'],
                                 :aetype     => options['type'],
                                 :priority   => 1,
                                 :substitute => true)
      create_field_value(instance_obj, field, options) unless options['value'].nil?
    else
      FactoryGirl.create(:miq_ae_field,
                         :method_id     => method_obj.id,
                         :name          => options['name'],
                         :aetype        => options['type'],
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
                 'name'  => 'test_field1',
                 'type'  => 'attribute',
                 'value' => 'test_attribute_value')
    create_field(class_obj, instance_obj, nil,
                 'name'  => 'test_field2',
                 'type'  => 'relationship',
                 'value' => @relations_value)
    create_field(class_obj, instance_obj, nil,
                 'name'  => 'test_field3',
                 'type'  => 'relationship',
                 'value' => 'test_relationship_value')
    create_field(class_obj, instance_obj, method_obj,
                 'name'  => 'test_method_input',
                 'type'  => 'attribute',
                 'value' => 'test_input_value')
  end

  def create_factory_data(domain_name, priority)
    domain   = FactoryGirl.create(:miq_ae_namespace, :name => domain_name,                     :priority => priority)
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
                                  :data     => "puts 1",
                                  :location => "inline")
    FactoryGirl.create(:miq_ae_instance,  :name => "#{domain_name}_test_instance1", :class_id => n1_1_c1.id)
    FactoryGirl.create(:miq_ae_method,
                       :class_id => n1_c1.id,
                       :name     => 'test2',
                       :scope    => "instance",
                       :language => "ruby",
                       :data     => "puts 1",
                       :location => "inline")
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
    @manageiq_domain = MiqAeNamespace.find_by_name("manageiq")
    @aen1            = MiqAeNamespace.find_by_name('manageiq_namespace_1')
    @aen1_1          = MiqAeNamespace.find_by_name('manageiq_namespace_1_1')
    @aen1_aec1       = MiqAeClass.find_by_name('manageiq_test_class_1')
    @aen1_aec2       = MiqAeClass.find_by_name('manageiq_test_class_2')
    @class_name       = @aen1_aec1.name
  end

  def set_customer_values
    @customer_domain    = MiqAeNamespace.find_by_name("customer")
    @customer_aen1      = MiqAeNamespace.find_by_name('customer_namespace_1')
    @customer_aen1_1    = MiqAeNamespace.find_by_name('customer_namespace_1_1')
    @customer_aen1_aec1 = MiqAeClass.find_by_name('customer_test_class_1')
    @customer_aen1_aec2 = MiqAeClass.find_by_name('customer_test_class_2')
    @class_name       = @aen1_aec1.name
  end

  def setup_export_dir
    @export_dir = File.join(Dir.tmpdir, "rspec_export_tests")
    @export_as  = "barney"
    @zip_file   = File.join(Dir.tmpdir, "yaml_model.zip")
    FileUtils.rm_rf(@export_dir) if File.exist?(@export_dir)
    FileUtils.rm_rf(@zip_file)   if File.exist?(@zip_file)
  end

  def check_counts(counts)
    MiqAeNamespace.count.should eql(counts['ns'])    if counts.key?('ns')
    MiqAeClass.count.should eql(counts['class']) if counts.key?('class')
    check_class_component_counts counts
    validate_additional_columns
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
    @additional_columns.each { |k, v| v.should eql(rel[k]) }
  end

  def check_class_component_counts(counts)
    MiqAeInstance.count.should eql(counts['inst'])  if counts.key?('inst')
    MiqAeMethod.count.should eql(counts['meth'])  if counts.key?('meth')
    MiqAeField.count.should eql(counts['field']) if counts.key?('field')
    MiqAeValue.count.should eql(counts['value']) if counts.key?('value')
  end

  def create_bogus_zip_file
    Zip::ZipFile.open(@zip_file, Zip::ZipFile::CREATE) do |zh|
      zh.file.open("first.txt", "w") { |f| f.puts "Hello world" }
      zh.dir.mkdir("mydir")
      zh.file.open("mydir/second.txt", "w") { |f| f.puts "Hello again" }
    end
  end
end
