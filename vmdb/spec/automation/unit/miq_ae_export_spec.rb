require "spec_helper"

describe MiqAeDatastore do
  it "should test the exported file count values" do
    begin
      export_fname = File.join(File.dirname(__FILE__), "test_export1.zip")
      File.write(export_fname, MiqAeDatastore.export)

      Zip::ZipFile.open(export_fname) do |zipfile|
        counts = zipfile.each_with_object(Hash.new { |h, k| h[k] = 0 }).each do |file, count|
                   if File.extname(file.to_s) == ".yaml"
                     data = YAML.load(file.get_input_stream.read)
                     count[data['object_type']] += 1
                     if data['object_type'] == 'class'
                       count['field'] += data['object']['schema'].length
                     elsif data['object_type'] == 'method'
                       count['field'] += data['object']['inputs'].length
                     end
                   end
                 end

        MiqAeDomain.count.should    eq(counts['domain'])
        # Add 1 to namespace count to adjust for the hidden namespace '$' that does not get exported
        MiqAeNamespace.count.should eq(counts['namespace'] + 1)
        MiqAeClass.count.should     eq(counts['class'])
        MiqAeInstance.count.should  eq(counts['instance'])
        MiqAeMethod.count.should    eq(counts['method'])
        MiqAeField.count.should     eq(counts['field'])
      end
    ensure
      File.delete(export_fname) if File.exist?(export_fname)
    end
  end
end
