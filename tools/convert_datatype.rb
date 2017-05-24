require 'find'
require 'yaml'

class_files = []
Find.find('db/fixtures/ae_datastore/ManageIQ') do |path|
  class_files << path if path =~ /.*\__class__.yaml$/ && !File.read(path).blank?
end

class_files.each do |file|
  yaml_file = YAML.load_file(file)
  yaml_file["object"]["schema"].each_with_index do |_field, index|
    if yaml_file["object"]["schema"][index]["field"]["datatype"].blank?
      yaml_file["object"]["schema"][index]["field"]["datatype"] = "string"
      File.open(file, 'w') { |f| f.write yaml_file.to_yaml }
    end
  end
end
