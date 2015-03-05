class OrchestrationTemplateHot < OrchestrationTemplate
  def parameter_groups
    content_hash = YAML.load(content)
    raw_groups = content_hash["parameter_groups"]

    if raw_groups
      indexed_parameters = parameters(content_hash).index_by(&:name)
      raw_groups.collect do |raw|
        OrchestrationTemplate::OrchestrationParameterGroup.new(
          :label       => raw["label"],
          :description => raw["description"],
          # Map each parameter name to its corresponding object
          :parameters  => raw["parameters"].collect { |name| indexed_parameters[name] }
        )
      end
    else
      # Create a single group to include all parameters
      [OrchestrationTemplate::OrchestrationParameterGroup.new(
        :label      => "Parameters",
        :parameters => parameters(content_hash)
      )]
    end
  end

  def parameters(content_hash = nil)
    content_hash = YAML.load(content) unless content_hash
    content_hash["parameters"].collect do |key, val|
      OrchestrationTemplate::OrchestrationParameter.new(
        :name          => key,
        :label         => val.key?('label') ? val['label'] : key.titleize,
        :data_type     => val['type'],
        :default_value => val['default'],
        :description   => val['description'],
        :hidden        => val['hidden'] == true,
        :constraints   => val.key?('constraints') ? parse_constraints(val['constraints']) : nil,
      )
    end
  end

  def self.eligible_manager_types
    [EmsOpenstack]
  end

  # return the parsing error message if not valid JSON; otherwise nil
  def validate_format
    YAML.parse(content) && nil if content
  rescue Psych::SyntaxError => err
    err.message
  end

  private

  def parse_constraints(raw_constraints)
    raw_constraints.collect do |raw_constraint|
      if raw_constraint.key? 'allowed_values'
        parse_allowed_values(raw_constraint)
      elsif raw_constraint.key? 'allowed_pattern'
        parse_pattern(raw_constraint)
      elsif raw_constraint.key? 'length'
        parse_length_constraint(raw_constraint)
      elsif raw_constraint.key? 'range'
        parse_value_constraint(raw_constraint)
      elsif raw_constraint.key? 'custom_constraint'
        parse_custom_constraint(raw_constraint)
      else
        raise MiqException::MiqParsingError, "Unknown constraint #{raw_constraint}"
      end
    end
  end

  def parse_allowed_values(hash)
    OrchestrationTemplate::OrchestrationParameterAllowed.new(
      :allowed_values => hash['allowed_values'],
      :description    => hash['description']
    )
  end

  def parse_pattern(hash)
    OrchestrationTemplate::OrchestrationParameterPattern.new(
      :pattern     => hash['allowed_pattern'],
      :description => hash['description']
    )
  end

  def parse_length_constraint(hash)
    OrchestrationTemplate::OrchestrationParameterLength.new(
      :min_length  => hash['length']['min'],
      :max_length  => hash['length']['max'],
      :description => hash['description']
    )
  end

  def parse_value_constraint(hash)
    OrchestrationTemplate::OrchestrationParameterRange.new(
      :min_value   => hash['range']['min'],
      :max_value   => hash['range']['max'],
      :description => hash['description']
    )
  end

  def parse_custom_constraint(hash)
    OrchestrationTemplate::OrchestrationParameterCustom.new(
      :custom_constraint => hash['custom_constraint'],
      :description       => hash['description']
    )
  end
end
