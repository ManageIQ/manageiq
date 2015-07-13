require "spec_helper"
include MiqAeYamlImportExportMixin

describe MiqAeMethodCompare do

  before do
    @domain = 'SPEC_DOMAIN'
    @namespace   = 'NS1'
    @classname   = 'CLASS1'
    @yaml_file   = File.join(File.dirname(__FILE__), 'miq_ae_copy_data', 'miq_ae_method_copy.yaml')
    MiqAeDatastore.reset
    EvmSpecHelper.import_yaml_model_from_file(@yaml_file, @domain)
    @export_dir = File.join(Dir.tmpdir, 'rspec_copy_tests')
    @yaml_model = YAML.load_file(@yaml_file)
  end

  context 'same methods' do
    before do
      prep_method_file_names('test_method')
    end

    it 'both methods in DB should be equivalent' do
      meth1  = MiqAeMethod.find_by_class_id_and_name(@class.id, @first_method)
      method_check_status(meth1, meth1, MiqAeMethodCompare::CONGRUENT_METHOD)
    end

    it 'one method in DB and other in YAML should be equivalent' do
      export_model(@domain)
      meth1 = MiqAeMethod.find_by_class_id_and_name(@class.id, @first_method)
      meth2 = MiqAeMethodYaml.new(@method1_file)
      method_check_status(meth1, meth2, MiqAeMethodCompare::CONGRUENT_METHOD)
    end
  end

  context 'method slightly off' do
    before do
      prep_method_file_names('test_method', 'test_method_diff_script')
    end

    it 'both method in DB should be incompatible' do
      meth1  = MiqAeMethod.find_by_class_id_and_name(@class.id, @first_method)
      meth2  = MiqAeMethod.find_by_class_id_and_name(@class.id, @second_method)
      method_check_status(meth1, meth2, MiqAeMethodCompare::INCOMPATIBLE_METHOD)
    end

    it 'one method in DB and other in YAML should be incompatible' do
      export_model(@domain)
      meth1 = MiqAeMethod.find_by_class_id_and_name(@class.id, @first_method)
      meth2 = MiqAeMethodYaml.new(@method2_file)
      method_check_status(meth1, meth2, MiqAeMethodCompare::INCOMPATIBLE_METHOD)
    end
  end

  context 'one parameter slightly off' do
    before do
      prep_method_file_names('test_method', 'test_method_diff_parameter')
    end

    it 'both method in DB should be compatible' do
      meth1  = MiqAeMethod.find_by_class_id_and_name(@class.id, @first_method)
      meth2  = MiqAeMethod.find_by_class_id_and_name(@class.id, @second_method)
      method_check_status(meth1, meth2, MiqAeMethodCompare::COMPATIBLE_METHOD)
    end

    it 'one method in DB and other in YAML should be compatible' do
      export_model(@domain)
      meth1 = MiqAeMethod.find_by_class_id_and_name(@class.id, @first_method)
      meth2 = MiqAeMethodYaml.new(@method2_file)
      method_check_status(meth1, meth2, MiqAeMethodCompare::COMPATIBLE_METHOD)
    end
  end

  def method_check_status(method1, method2, status)
    diff_obj = MiqAeMethodCompare.new(method1, method2)
    diff_obj.compare
    diff_obj.status.should equal(status)
  end

  def prep_method_file_names(meth1 = nil, meth2 = nil)
    @first_method = meth1 if meth1
    @second_method = meth2 if meth2
    @method1_file = File.join(@export_dir, @domain, @namespace,
                              "#{@classname}.class", '__methods__', "#{meth1}.yaml") if meth1
    @method2_file = File.join(@export_dir, @domain, @namespace,
                              "#{@classname}.class", '__methods__', "#{meth2}.yaml") if meth2
    @ns1 = MiqAeNamespace.find_by_fqname("#{@domain}/#{@namespace}")
    @class = MiqAeClass.find_by_namespace_id_and_name(@ns1.id, @classname)
  end

  def export_model(domain, export_options = {})
    FileUtils.rm_rf(@export_dir) if File.exist?(@export_dir)
    export_options['export_dir'] = @export_dir if export_options.empty?
    MiqAeExport.new(domain, export_options).export
  end
end
