require "spec_helper"

module MiqAeDatastoreConverter
  include MiqAeDatastore
  describe "XML2YAML Converter" do
    before(:each) do
      MiqServer.my_server_clear_cache
      MiqAeDatastore.reset
    end

    after(:each) do
      MiqAeDatastore.reset
    end
    def setup_export_dir
      @domain     = 'TEST'
      @export_dir = File.join(Dir.tmpdir, "rspec_export_tests")
      @zip_file   = File.join(Dir.tmpdir, "yaml_model.zip")
      FileUtils.rm_rf(@export_dir) if File.exist?(@export_dir)
      FileUtils.rm_rf(@zip_file)   if File.exist?(@zip_file)
    end

    context "convert xml to yaml" do
      before(:each) do
        setup_export_dir
        MiqAeDatastore.reset
        @root_xml = <<-'XML'
        <MiqAeDatastore version='1.0'>
          <MiqAeClass name="AUTOMATE" namespace="evm">
            <MiqAeSchema>
              <MiqAeField name="overlay_method"  aetype="method" display_name="overlay method" />
              <MiqAeField name="attr1"    aetype="attribute" default_value=""  display_name="Attribute1"/>
              <MiqAeField name="connect_to"    aetype="relationship" default_value=""  display_name="Relationship"/>
            </MiqAeSchema>
            <MiqAeInstance name="test1">
              <MiqAeField name="overlay_method">root_method</MiqAeField>
            </MiqAeInstance>
            <MiqAeInstance name="test2">
              <MiqAeField name="connect_to">/root/evm/AUTOMATE/test1</MiqAeField>
            </MiqAeInstance>
        <MiqAeMethod name="root_method" language="ruby" location="inline" scope="instance">
        <![CDATA[
        begin
          $evm.log("info", "#{@method} - Root:<$evm.root> Begin Attributes")
          $evm.root.attributes.sort.each do |k, v|
            $evm.log("info", "#{@method} - Root:<$evm.root> Attributes - #{k}: #{v}")
          end
          $evm.log("info", "#{@method} - Root:<$evm.root> End Attributes")
          $evm.log("info", "#{$evm.class.name}")
                   $evm.root['method_executed']  = "root"
        end
              ]]>
            </MiqAeMethod>
          </MiqAeClass>
        </MiqAeDatastore>
        XML
      end

      it "convert a domain from XML into a ZIP and import it in" do
        MiqAeDatastore::XmlYamlConverter.convert(@root_xml, @domain, 'zip_file' => @zip_file)
        MiqAeNamespace.count.should eql(0)
        MiqAeClass.count.should eql(0)
        MiqAeInstance.count.should eql(0)
        MiqAeField.count.should eql(0)
        import_options = {}
        import_options['preview'] = false
        import_options['zip_file'] = @zip_file
        MiqAeImport.new(@domain, import_options).import
        MiqAeNamespace.count.should eql(2)
        MiqAeClass.count.should eql(1)
        MiqAeInstance.count.should eql(2)
      end

      it "convert a domain from XML into filesystem and import it in" do
        MiqAeDatastore::XmlYamlConverter.convert(@root_xml, @domain, 'export_dir' => @export_dir)
        MiqAeNamespace.count.should eql(0)
        MiqAeClass.count.should eql(0)
        MiqAeInstance.count.should eql(0)
        MiqAeField.count.should eql(0)
        import_options = {}
        import_options['preview'] = false
        import_options['import_dir'] = @export_dir
        MiqAeImport.new(@domain, import_options).import
        MiqAeNamespace.count.should eql(2)
        MiqAeClass.count.should eql(1)
        MiqAeInstance.count.should eql(2)
      end

    end
  end
end
