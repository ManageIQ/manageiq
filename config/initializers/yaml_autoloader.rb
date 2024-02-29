# Autoload Rails Models unless called from safe_load
# see https://github.com/collectiveidea/delayed_job/blob/master/lib/delayed/psych_ext.rb

# Psych::ClassLoader::Restricted is the class_loader if you use safe_load and was
# added in psych 2.0.0:
# https://github.com/ruby/psych/commit/2c644e184192975b261a81f486a04defa3172b3f
#
# Note, this is used to autoload constants serialized as yaml from one process and loaded in another such as through
# args in the MiqQueue. An alternative would be to eager load all of our autoload_paths in all processes.
#
# This is still needed in some areas for zeitwerk, such as YAML files for tests in the manageiq-providers-vmware
# that reference a constant: RbVmomi::VIM::TaskEvent
Psych::Visitors::ToRuby.prepend(Module.new do
  def resolve_class(klass_name)
    (class_loader.class != Psych::ClassLoader::Restricted && klass_name && klass_name.safe_constantize) || super
  end
end)
