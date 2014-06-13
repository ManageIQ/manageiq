require "spec_helper"

describe MiqAeDatastore do
  before do
    @export_fname = File.join(File.dirname(__FILE__), "test_export1.xml")
    @defaults_miq_ae_field = {}
    @defaults_miq_ae_field[:message]    = MiqAeField.default(:message)
    @defaults_miq_ae_field[:substitute] = MiqAeField.default(:substitute).to_s
  end

  after do
    File.delete(@export_fname) if File.exist?(@export_fname)
  end

  it "should test file export" do
    -> { MiqAeDatastore.export }.should_not raise_error
  end

  it "should test the exported file count values" do
    export_file = MiqAeDatastore.export
    File.open(@export_fname, "w") { |f| f.write(export_file) }
    export_hash = XmlHash.loadFile(@export_fname)

    export_hash.to_h(:symbols => false)["MiqAeClass"].length.should eql(MiqAeClass.count)

    field_length_total = 0
    methods_length = 0
    instances_length = 0

    classes_export = export_hash.to_h(:symbols => false)["MiqAeClass"]
    classes_export.each_with_index do |c, c_idx|
      $log.info("Class length: #{c_idx}")
      aec = c

      schema_aec = aec["MiqAeSchema"]
      if schema_aec
        fields_aec = sanitize_miq_ae_fields(schema_aec.first["MiqAeField"])
        $log.info("fields length   : #{fields_aec.length}")
        $log.info("fields name     : #{fields_aec.collect { |item| item["name"] }.join(", ")}")
        field_length_total += fields_aec.length
      end

      methods_aec = aec["MiqAeMethod"]
      if methods_aec
        methods_length += methods_aec.length

        methods_aec.each do |method_aec|
          method_fields_aec = sanitize_miq_ae_fields(method_aec["MiqAeField"])
          if method_fields_aec
            $log.info("method fields length: #{method_fields_aec.length}")
            $log.info("method fields name  : #{method_fields_aec.collect { |item| item["name"] }.join(", ")}")
            field_length_total += method_fields_aec.length
          end
        end
      end

      instances_export = aec["MiqAeInstance"]
      instances_length += instances_export.length unless instances_export.nil?
    end

    field_length_total.should eql(MiqAeField.count)
    instances_length.should eql(MiqAeInstance.count)
    methods_length.should eql(MiqAeMethod.count)
  end

end
