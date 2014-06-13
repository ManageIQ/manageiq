require Rails.root.join('lib/migration_helper')

class ConvertOldStatesToNewFormat < ActiveRecord::Migration
  # NOTE: This migration is reentrant so that any failures in the middle of the
  # data migration do not rollback the entire set, and so that not all of the
  # data is migrated in a single transaction.

  include MigrationHelper

  self.no_transaction = true

  class State < ActiveRecord::Base; end

  require 'miq-xml'
  require 'parallel'

  def up
    say_with_time("Converting old states to new format") do
      rows = State.where(:data => nil).count
      say_batch_started(rows)
      return if rows == 0

      resources = State.where(:data => nil).group(:resource_type, :resource_id).select([:resource_type, :resource_id, "COUNT(*) as state_count"])

      # Don't pass AR objects over process boundaries
      resources = resources.collect { |r| {:resource_type => r.resource_type, :resource_id => r.resource_id, :state_count => r.state_count.to_i} }

      # Go resource by resource in parallel
      processors = ENV['MIGRATION_PROCESSES'] && ENV['MIGRATION_PROCESSES'].to_i  # nil => all processors, 0 => no parallelism

      Parallel.each(resources,
        :in_processes => processors,
        :finish       => lambda { |resource, _| say_batch_processed(resource[:state_count]) }
      ) do |r|
        ActiveRecord::Base.connection.reconnect! unless processors == 0
        states = State.where(r.except(:state_count)).order("timestamp DESC, id DESC").all
        states = cleanup_bad_states(states)
        migrate_states_to_new_format(states)
      end

      ActiveRecord::Base.connection.reconnect! unless processors == 0
    end
  end

  def down
  end

  def cleanup_bad_states(states)
    first_full = false
    second_full = false
    states_to_keep = []
    states.each do |state|
      # haven't seen a full yet
      if !first_full
        # first full state found
        if state.scantype == 'full'
          first_full = true
          states_to_keep << state
          # delete diff states prior to the first full state
        else
          state.destroy
        end
        # only one full state found so far
      elsif !second_full
        # delete subsequent full states
        if state.scantype == 'full'
          state.destroy
          second_full = true
        else
          states_to_keep << state
        end
        # delete everything after second full state
      else
        state.destroy
      end
    end
    states_to_keep
  end

  def migrate_states_to_new_format(states)
    return if states.blank?
    spec = states.first.resource_type.constantize.to_model_hash_options

    connection.transaction do
      full_xml = nil
      states.each do |s|
        xml_data = fix_old_state_xml(s.xml_data)

        state_xml = MIQRexml.load(xml_data)
        if s.scantype == "full"
          full_xml = state_xml
        else
          full_xml.xmlPatch(state_xml, -1)
        end
        root = full_xml.root
        data = process_element(spec, root, root.name.classify.constantize)
        s.update_attribute(:data, data)
      end
    end
  end

  # Fixes unescaped HTML entities in all attributes that will cause
  #   the newer XML parser to raise an IllegalCharacter Exception.
  def fix_old_state_xml(xml)
    xml.gsub(/\='([^']+?)'/) do |m|
      new_value = $1.gsub(/&(?!(?:apos|quot|amp|lt|gt|nbsp|iexcl|cent|pound|curren|yen|brvbar|sect|uml|copy|ordf|laquo|not|shy|reg|macr|deg|plusmn|sup2|sup3|acute|micro|para|middot|cedil|sup1|ordm|raquo|frac14|frac12|frac34|iquest|Agrave|Aacute|Acirc|Atilde|Auml|Aring|AElig|Ccedil|Egrave|Eacute|Ecirc|Euml|Igrave|Iacute|Icirc|Iuml|ETH|Ntilde|Ograve|Oacute|Ocirc|Otilde|Ouml|times|Oslash|Ugrave|Uacute|Ucirc|Uuml|Yacute|THORN|szlig|agrave|aacute|acirc|atilde|auml|aring|aelig|ccedil|egrave|eacute|ecirc|euml|igrave|iacute|icirc|iuml|eth|ntilde|ograve|oacute|ocirc|otilde|ouml|divide|oslash|ugrave|uacute|ucirc|uuml|yacute|thorn|yuml|OElig|oelig|Scaron|scaron|Yuml|fnof|circ|tilde|Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega|alpha|beta|gamma|delta|epsilon|zeta|eta|theta|iota|kappa|lambda|mu|nu|xi|omicron|pi|rho|sigmaf|sigma|tau|upsilon|phi|chi|psi|omega|thetasym|upsih|piv|ensp|emsp|thinsp|zwnj|zwj|lrm|rlm|ndash|mdash|lsquo|rsquo|sbquo|ldquo|rdquo|bdquo|dagger|Dagger|bull|hellip|permil|prime|Prime|lsaquo|rsaquo|oline|frasl|euro|image|weierp|real|trade|alefsym|larr|uarr|rarr|darr|harr|crarr|lArr|uArr|rArr|dArr|hArr|forall|part|exist|empty|nabla|isin|notin|ni|prod|sum|minus|lowast|radic|prop|infin|ang|and|or|cap|cup|int|there4|sim|cong|asymp|ne|equiv|le|ge|sub|sup|nsub|sube|supe|oplus|otimes|perp|sdot|lceil|rceil|lfloor|rfloor|lang|rang|loz|spades|clubs|hearts|diams|#\d+);)/, "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
      "='#{new_value}'"
    end
  end

  def process_element(spec, object, klass)
    h1 = process_children(spec, object, klass)
    h2 = process_attributes(spec, object, klass)
    h1.merge!(h2)
    return nil if h1.empty?
    h1.merge!(:class => klass.name)
  end

  def process_attributes(spec, element, klass)
    columns = extract_columns_from_spec(spec)

    attrs = element.attributes

    # Loop through the spec's columns and extract from the attributes
    columns.each_with_object({}) do |k, h|
      k_str = k.to_s

      v = attrs[k_str]
      next if v.nil?

      col = klass.columns_hash_with_virtual[k_str]
      next unless col

      h[k] = col.type_cast(v)
    end
  end

  def process_children(spec, element, klass)
    includes = extract_includes_from_spec(spec)

    elements = element.children

    # Loop through child elements and filter against the includes
    elements.each_with_object({}) do |e, h|
      k = e.name.to_sym
      next unless includes.has_key?(k)

      v = if k == :tags
        process_tags(e.children)
      elsif e.attributes['_macro_'] == 'has_many'
        ref = klass.reflections_with_virtual[k]
        process_has_many(includes[k], e.children, ref.klass) if ref
      else
        ref = klass.reflections_with_virtual[k]
        process_element(includes[k], e, ref.klass) if ref
      end

      h[k] = v unless v.blank?
    end
  end

  def process_has_many(spec, elements, klass)
    elements.
      collect { |e| process_element(spec, e, klass) }.
      compact.
      sort_by! { |h| h[:id] }
  end

  def process_tags(tags)
    tags.collect do |t|
      h = Hash[t.attributes.to_h.symbolize_keys.sort]

      [:id, :entry_id, :category_id].each do |attribute|
        h[attribute] = cast_to_integer(h[attribute])
      end

      [:category_single_value].each do |attribute|
        h[attribute] = cast_to_boolean(h[attribute])
      end

      h
    end
  end

  def extract_columns_from_spec(spec)
    ((spec[:columns] || []) + [:id]).sort
  end

  def extract_includes_from_spec(spec)
    spec[:include] || {}
  end

  def cast_to_integer(value)
    @integer_caster ||= VirtualColumn.new("dummy", :type => :integer)
    @integer_caster.type_cast(value)
  end

  def cast_to_boolean(value)
    @boolean_caster ||= VirtualColumn.new("dummy", :type => :boolean)
    @boolean_caster.type_cast(value)
  end
end
