$:.push("#{File.dirname(__FILE__)}/extensions")
Dir.glob(File.expand_path(File.join(File.dirname(__FILE__), "extensions", "*.rb"))).sort.each do |f|
  # TODO: extensions are order dependent, see #3252
  require File.basename(f, ".*")
end
