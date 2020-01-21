# Needs to be run with script/runner
#

# Load the Policy Class so that we get PolicySet defined
begin
  Policy.find(1)
rescue
end

# ext = "xml"
ext = "yaml"

dir = Dir.pwd

MiqPolicySet.all.each do |ps|
  begin
    contents = ps.export_to_yaml if ext == "yaml"
    contents = ps.export_to_xml  if ext == "xml"

    fname = File.join(dir, "policy_profile#{ps.id}.#{ext}")
    puts "Creating #{fname}"
    f = File.new(fname, "w")
    f << contents
    f.close
  rescue ActiveRecord::RecordNotFound
    next
  end
end
