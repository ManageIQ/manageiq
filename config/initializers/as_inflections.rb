ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.singular(/(base)s$/i, '\1') # Override rails default: "bases".singularize => "base" not "basis"
end
