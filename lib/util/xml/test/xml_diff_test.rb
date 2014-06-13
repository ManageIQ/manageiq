# Only run if we are calling this script directly
begin
  $:.push("#{File.dirname(__FILE__)}/../..")
  require 'miq-xml'
  
  diff_dir = "d:/temp/xml"
  cfg = {
    :file1 => File.join(diff_dir, "drift1.xml"), 
    :file2 => File.join(diff_dir, "drift2.xml"),
    :diff => File.join(diff_dir,  "diff.xml"),
    :patch => File.join(diff_dir, "patch.xml")
  }

  # Comment follow line to patch xml and get original file back
  #@compare = true
  if @compare
    stats = {}
    xml1 = MiqXml.loadFile(cfg[:file2])
    xml2 = MiqXml.loadFile(cfg[:file1])
		
    delta = xml1.xmlDiff(xml2, stats)
    File.open(cfg[:diff], "w") {|f| delta.write(f,0)}
  else		
    base = MiqXml.loadFile(cfg[:file2])
    diff = MiqXml.loadFile(cfg[:diff])
    base.extendXmlDiff
    stats = base.xmlPatch(diff,-1)
    File.open(cfg[:patch], "w") {|f| base.write(f,0)}
  end
  
  puts "done"
rescue => err
  puts err
  puts err.backtrace.join("\n")
end