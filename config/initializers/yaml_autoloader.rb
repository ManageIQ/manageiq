# Autoload Rails Models
# see https://github.com/collectiveidea/delayed_job/blob/master/lib/delayed/psych_ext.rb

Psych::Visitors::ToRuby.prepend Module.new {
  def resolve_class(klass_name)
    klass_name && klass_name.safe_constantize || super
  end
}
