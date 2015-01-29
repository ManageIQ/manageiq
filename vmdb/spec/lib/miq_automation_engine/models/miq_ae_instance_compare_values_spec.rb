require "spec_helper"
include MiqAeYamlImportExportMixin
describe MiqAeInstanceCompareValues do

  before do
    @domain = 'SPEC_DOMAIN'
    @namespace   = 'NS1'
    @classname   = 'CLASS1'
    @yaml_file   = File.join(File.dirname(__FILE__), 'miq_ae_copy_data', 'miq_ae_method_copy.yaml')
    MiqAeDatastore.reset
    EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
    @export_dir = Dir.mktmpdir
    @yaml_model = YAML.load_file(@yaml_file)
  end

  after(:each) do
    FileUtils.remove_entry_secure(@export_dir) if Dir.exist?(@export_dir)
  end

  context "same instances" do
    before do
      prep_instance_file_names("instance1")
    end

    it "both instances in DB should be equivalent" do
      inst1  = MiqAeInstance.find_by_class_id_and_name(@class.id, @first_instance)
      instance_check_status(inst1, inst1, MiqAeInstanceCompareValues::CONGRUENT_INSTANCE)
    end

    it "one instance in DB and other in YAML should be equivalent" do
      export_model(@domain)
      inst1 = MiqAeInstance.find_by_class_id_and_name(@class.id, @first_instance)
      inst2 = MiqAeInstanceYaml.new(@instance1_file)
      instance_check_status(inst1, inst2, MiqAeInstanceCompareValues::CONGRUENT_INSTANCE)
    end
  end

  context 'add a field in one of the instances' do
    before do
      prep_instance_file_names('instance1', 'delete1')
    end

    it 'both instances in DB should be compatible' do
      inst1  = MiqAeInstance.find_by_class_id_and_name(@class.id, @first_instance)
      inst2  = MiqAeInstance.find_by_class_id_and_name(@class.id, @second_instance)
      instance_check_status(inst1, inst2, MiqAeInstanceCompareValues::COMPATIBLE_INSTANCE)
    end

    it "one instance in DB and other in YAML should be compatible" do
      export_model(@domain)
      inst1 = MiqAeInstance.find_by_class_id_and_name(@class.id, @first_instance)
      inst2 = MiqAeInstanceYaml.new(@instance2_file)
      instance_check_status(inst1, inst2, MiqAeInstanceCompareValues::COMPATIBLE_INSTANCE)
    end

  end

  def instance_check_status(instance1, instance2, status)
    diff_obj = MiqAeInstanceCompareValues.new(instance1, instance2)
    diff_obj.compare
    diff_obj.status.should equal(status)
  end

  def prep_instance_file_names(inst1 = nil, inst2 = nil)
    @first_instance = inst1 if inst1
    @second_instance = inst2 if inst2
    @instance1_file = File.join(@export_dir, @domain, @namespace, "#{@classname}.class", "#{inst1}.yaml") if inst1
    @instance2_file = File.join(@export_dir, @domain, @namespace, "#{@classname}.class", "#{inst2}.yaml") if inst2
    @ns1 = MiqAeNamespace.find_by_fqname("#{@domain}/#{@namespace}")
    @class = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @classname)
  end

  def export_model(domain, export_options = {})
    FileUtils.rm_rf(@export_dir) if File.exist?(@export_dir)
    export_options['export_dir'] = @export_dir if export_options.empty?
    MiqAeExport.new(domain, export_options).export
  end
end
