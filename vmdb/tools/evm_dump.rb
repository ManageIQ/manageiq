LOG_DIR = "./"
logfile = File.join(LOG_DIR, "evm_dump.log")
File.delete(logfile) if File.exists?(logfile)
$log = VMDBLogger.new(logfile)
$log.level = VMDBLogger.const_get("DEBUG")

yml_fnames = []

def log(level, msg)
  puts "[#{Time.now.utc}] #{level.to_s.upcase}: #{msg}"
  $log.send(level, msg)
end

def yml_fname(klass)
  yml_fname = File.join(LOG_DIR, "#{klass.name.underscore}.yml")
end

def yml_dump(yml_fname, items)
  File.delete(yml_fname) if File.exists?(yml_fname)
  File.open(yml_fname, "w") { |fd| fd.write(YAML.dump(items)) }
end

### Main

# verify we are in the vmdb directory
unless File.exists?('app')
  log :error, "Please run this script using 'script/runner miq_queue_dump.rb' from vmdb directory"
  exit 1
end

# NOTE: Models that are not needed in dump can be commented directly in list.
MODELS = [
  AssignedServerRole,
  Configuration,
  Job,
  MiqEnterprise,
  MiqQueue,
  MiqServer,
  MiqTask,
  MiqWorker,
  ServerRole,
  UiTask,
  Zone
]
#

MODELS.each do |klass|
  log :info, "Getting #{klass} objects"
  items = klass.find(:all)
  if items.length > 0
    fname = yml_fname(klass)
    yml_fnames << fname
    log :info, "Writing #{items.length} #{klass} objects to #{fname}"
    yml_dump(fname, items)
  else
    log :info, "Found #{items.length} #{klass} objects"
  end
end

if yml_fnames.length > 0
  zip_fname = File.join(LOG_DIR, "evm_dump.zip")
  File.delete(zip_fname) if File.exists?(zip_fname)
  cmdline = "zip #{zip_fname} #{logfile}"
  yml_fnames.each { |fname| cmdline << " #{fname}" }
  log :info, "Zipping dump into #{zip_fname}"
  system(cmdline)
  yml_fnames.each { |fname| File.delete(fname) }
end

log :info, "Done"

exit 0
