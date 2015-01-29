require "spec_helper"
include MiqAeYamlImportExportMixin
describe MiqAeClassCompareFields do
  before do
    @domain = 'SPEC_DOMAIN'
    @namespace   = 'NS1'
    @yaml_folder = File.join(File.dirname(__FILE__), 'miq_ae_copy_data')
    MiqAeDatastore.reset
    @export_dir = Dir.mktmpdir
  end

  after(:each) do
    FileUtils.remove_entry_secure(@export_dir) if Dir.exist?(@export_dir)
  end

  context "same fields" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy1.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS1")
    end

    it "both class in DB should be equivalent" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class_check_status(class1, class1, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
    end

    it "one class in DB and other in YAML should be equivalent" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class1_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
    end
  end

  context "same fields mixed case" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy2.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS1", "MIXED_CASE_NAMES")
    end

    it "both class in DB should be equivalent" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
    end

    it "one class in DB and other in YAML should be equivalent" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::CONGRUENT_SCHEMA)
    end
  end

  context "same field but aetype changes" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy3.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS1", "CLASS_AETYPE_OFF")
    end

    it "both classes in DB should be incompatible" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end

    it "one class in DB and other in YAML should be incompatible" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end
  end

  context "same field but datatype changes" do
    before(:each) do
      @yaml_file   = File.join(@yaml_folder, 'class_copy4.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS1", "CLASS_DATATYPE_OFF")
    end

    it "both classes in DB should be incompatible" do
      ns1 = MiqAeNamespace.find_by_fqname("#{@domain}/#{@namespace}")
      class1 = MiqAeClass.find_by_namespace_id_and_name(ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end

    it "one class in DB and other in YAML should be incompatible" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end
  end

  context "same fields but priority changes" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy5.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS1", "CLASS_PRIORITY_OFF")
    end

    it "both classes in DB should be compatible" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::COMPATIBLE_SCHEMA)
    end

    it "one class in DB and other in YAML should be compatible" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::COMPATIBLE_SCHEMA)
    end
  end

  context "mostly same fields except a new additon" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy6.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS_ADD_A_FIELD", "CLASS1")
    end

    it "both classes in DB should be compatible" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::COMPATIBLE_SCHEMA)
    end

    it "one class in DB and other in YAML should be compatible" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::COMPATIBLE_SCHEMA)
    end
  end

  context "mostly same fields except a deletion of a in use field" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy7.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS_IN_USE_FIELD_DELETED", "CLASS1")
    end

    it "both classes in DB should be incompatible" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end

    it "one class in DB and other in YAML should be incompatible" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end
  end

  context "mostly same fields except a deletion of a field not in use" do
    before do
      @yaml_file   = File.join(@yaml_folder, 'class_copy8.yaml')
      EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
      prep_class_file_names("CLASS_FIELD_DELETED", "CLASS1")
    end

    it "both classes in DB should be incompatible" do
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @second_class)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end

    it "one class in DB and other in YAML should be incompatible" do
      export_model(@domain)
      class1 = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @first_class)
      class2 = MiqAeClassYaml.new(@class2_file)
      class_check_status(class1, class2, MiqAeClassCompareFields::INCOMPATIBLE_SCHEMA)
    end
  end

  def class_check_status(class1, class2, status)
    diff_obj = MiqAeClassCompareFields.new(class1, class2)
    diff_obj.compare
    diff_obj.status.should equal(status)
  end

  def prep_class_file_names(class1 = nil, class2 = nil)
    @first_class = class1 if class1
    @second_class = class2 if class2
    @class1_file = File.join(@export_dir, @domain, @namespace, "#{@first_class}.class", "__class__.yaml") if class1
    @class2_file = File.join(@export_dir, @domain, @namespace, "#{@second_class}.class", "__class__.yaml") if class2
    @ns1 = MiqAeNamespace.find_by_fqname("#{@domain}/#{@namespace}")
  end

  def export_model(domain, export_options = {})
    FileUtils.rm_rf(@export_dir) if File.exist?(@export_dir)
    export_options['export_dir'] = @export_dir if export_options.empty?
    MiqAeExport.new(domain, export_options).export
  end
end
