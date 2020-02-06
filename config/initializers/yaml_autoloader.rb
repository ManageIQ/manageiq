# Autoload Rails Models unless called from safe_load
# see https://github.com/collectiveidea/delayed_job/blob/master/lib/delayed/psych_ext.rb

# Psych::ClassLoader::Restricted is the class_loader if you use safe_load and was
# added in psych 2.0.0:
# https://github.com/ruby/psych/commit/2c644e184192975b261a81f486a04defa3172b3f
# Note, ruby 2.4.0 shipped with psych 2.2.2+.  This class_loader would not work with ruby 2.3 and older.
Psych::Visitors::ToRuby.prepend Module.new {
  def resolve_class(klass_name)
    (class_loader.class != Psych::ClassLoader::Restricted && klass_name && klass_name.safe_constantize) || super
  end
}
