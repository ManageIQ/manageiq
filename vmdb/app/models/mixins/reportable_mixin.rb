module ReportableMixin
  extend ActiveSupport::Concern
  included do
    cattr_accessor :aar_options, :aar_columns
  end

  module ClassMethods
    def report_table(number = :all, options = {})
      only = options.delete(:only).collect {|c| "category." == c[0..8] ? nil : c}.compact
      except = options.delete(:except)
      includes = options.delete(:include)
      includes_categories = includes.delete("categories") if includes
      record_class = options.delete(:record_class) || Ruport::Data::Record
      tag_filters = options.delete(:tag_filters)
      limit = includes ? options.delete(:limit) : nil # consume the limit here so that is can be applied later after includes are added in.

      unless options.delete(:eager_loading) == false
        options[:include] = get_include_for_find(includes)
        options[:eager_loading] = false
      end

      cond_list = []
      options[:include].each_key {|k|
        if !options[:include][k].empty?
          cond_list.push("#{k.pluralize}.id IS NOT NULL")
        end
      } if options[:include]
      mycond = cond_list.empty? || tag_filters ? nil : "#{cond_list.join(" and ")}"

      db = self
      method = db.respond_to?(:find_filtered) ? :find_filtered : :find
      case method
      when :find_filtered
        if /[.]+/ =~ options[:conditions] && options[:include] && tag_filters
          # Has includes and condition references included table.
          # Can't use tagged find in this case because it does not support includes.
          # We have to do a tag search woithout the conditions to get the list that matches the tags.
          # Then we do a normal find with the conditions. Finally, we loop through list from the normal
          # find and keep only the records that are in the has_tags list.
          new_opts = options.merge(:tag_filters => tag_filters); new_opts.delete(:conditions)
          has_tags, total_count = db.send(method, :all, new_opts.merge(:conditions => mycond))
          options[:conditions] = "(#{options[:conditions]}) and #{mycond}" if mycond
          options.delete(:eager_loading)
          unfiltered = db.find(number, options)
          records = unfiltered.collect {|r| r if has_tags.include?(r)}.compact.flatten
        else
          options[:conditions] = options[:conditions] ? "(#{options[:conditions]}) and #{mycond}" : mycond if mycond
          records = db.send(method, :all, options.merge(:tag_filters => tag_filters)).first.flatten
        end
      when :find
        options.delete(:eager_loading)
        records = db.send(method, :all, options).flatten
      end

      MiqReportable.records2table(records,
        :include => includes,
        :include_categories => includes_categories,
        :only => only,
        :except => except,
        :column_names => db.aar_columns,
        :record_class => record_class,
        :tag_filters => tag_filters,
        :limit => limit
      )
    end

    def search(count = :all, options = {})
      conditions = options.delete(:conditions)
      filter = options.delete(:filter)

      # Do normal find
      results = []
      self.find(count, :conditions => conditions, :include => get_include_for_find(options[:include])).each {|obj|
        if filter
          expression = self.filter.to_ruby
          expr = Condition.subst(expression, obj, inputs)
          next unless eval(expr)
        end

        entry = {:obj => obj}
        obj.search_includes(entry, options[:include]) if options[:include]
        results.push(entry)
      }

      results
    end


    # private

    def get_include_for_find(report_option)
      includes = report_option
      if includes.is_a?(Hash)
        result = {}
        includes.each do |k,v|
          v[:include] = v["include"] if v["include"]
          if v.empty? || !v[:include]
            result.merge!(k => {})
          else
            result.merge!(k => get_include_for_find(v[:include]))
          end
        end
        result
      elsif includes.is_a?(Array)
        result = {}
        includes.each {|i| result.merge!(i => {}) }
        result
      else
        includes
      end
    end
  end

  def reportable_data(options = {})
    data_records = [get_attributes_with_options(options)]
    self.class.aar_columns |= data_records.first.keys

    data_records =
      add_includes(data_records, options) if options[:include]
    data_records
  end

  private

  def add_includes(data_records, options)
    includes = options[:include]
    include_has_options = includes.is_a?(Hash)
    associations = include_has_options ? includes.keys : Array(includes)

    associations.each do |association|
      existing_records = data_records.dup
      data_records = []

      if include_has_options
        assoc_options = includes[association].merge({
          :qualify_attribute_names => association })
      else
        assoc_options = { :qualify_attribute_names => association }
      end

      if association == "categories"
        association_objects = []
        assochash = {}
        includes["categories"][:only].each {|c|
          entries = Classification.all_cat_entries(c, self)
          entarr = []
          entries.each {|e| entarr.push(e.description)}
          assochash["categories." + c] = entarr unless entarr.empty?
        }
        # join the the category data together
        longest = 0
        idx = 0
        assochash.each_key {|k| longest = assochash[k].length if assochash[k].length > longest}
        longest.times {
          nh = {}
          assochash.each_key {|k| nh[k] = assochash[k][idx].nil? ? assochash[k].last : assochash[k][idx]}
          association_objects.push(OpenStruct.new("reportable_data" => [nh]))
          idx += 1
        }
     else
        # if respond_to?(:find_filtered_children)
        #   association_objects = self.find_filtered_children(association, options).first.flatten.compact
        # else
          association_objects = [send(association)].flatten.compact
        # end
      end

      existing_records.each do |existing_record|
        if association_objects.empty?
          data_records << existing_record
        else
          association_objects.each do |obj|
            association_records = obj.reportable_data(assoc_options)
            association_records.each do |assoc_record|
              data_records << existing_record.merge(assoc_record)
            end
            self.class.aar_columns |= data_records.last.keys
          end
        end
      end
    end
    data_records
  end

  def get_attributes_with_options(options = {})
    only_or_except =
      if options[:only] || options[:except]
      { :only => options[:only], :except => options[:except] }
    end
    return {} unless only_or_except

    attrs = {}
    options[:only].each { |a| attrs[a] = self.send(a) if self.respond_to?(a) }
    attrs = attrs.inject({}) { |h,(k,v)|
              h["#{options[:qualify_attribute_names]}.#{k}"] = v
              h
            } if options[:qualify_attribute_names]
    attrs
  end
end
