# Needs to be run with script/runner
#
dir = Dir.pwd
# ext = "xml"
ext = "yaml"

Policy.all.each do |p|
  fname = File.join(dir, "policy#{p.id}.#{ext}")
  puts "Creating #{fname}"
  f = File.new(fname, "w")
  f << p.export_to_yaml if ext == "yaml"
  f << p.export_to_xml  if ext == "xml"
  f.close
end
