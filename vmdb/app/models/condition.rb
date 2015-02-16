class Condition < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  include UuidMixin
  before_validation :default_name_to_guid, :on => :create

  validates_presence_of     :name, :description, :guid, :modifier, :expression, :towhat
  validates_uniqueness_of   :name, :description, :guid
  validates_inclusion_of    :modifier, :in => %w{ allow deny }

  acts_as_miq_taggable
  acts_as_miq_set_member

  include ReportableMixin

  belongs_to :miq_policy
  has_and_belongs_to_many :miq_policies

  serialize :expression
  serialize :applies_to_exp

  attr_accessor :reserved

  def applies_to?(rec, inputs={})
    return false if !self.towhat.nil? && rec.class.base_model.name != self.towhat
    return true  if self.applies_to_exp.nil?

    Condition.evaluate(self, rec, inputs, :applies_to_exp)
  end

  def self.conditions
    pluck(:expression)
  end

  def self.evaluate(cond, rec, inputs={}, attr=:expression)
    expression = cond.send(attr)
    name = cond.respond_to?(:description) ? cond.description : cond.respond_to?(:name) ? cond.name : nil
    if expression.is_a?(MiqExpression)
      mode = "object"
    else
      mode = expression["mode"]
    end

    case mode
    when "script"
      result = eval(expression["expr"].strip)
    when "tag"
      case expression["include"]
      when "any"
        result = false
      when "all", "none"
        result = true
      else
        raise "condition '#{name}', include value \"#{expression["include"]}\", is invalid. Should be one of \"any, all or none\""
      end

      result = expression["include"] != "any"
      expression["tag"].split.each {|tag|
        if rec.is_tagged_with?(tag, :ns => expression["ns"])
          result = true if expression["include"] == "any"
          result = false if expression["include"] == "none"
        else
          result = false if expression["include"] == "all"
        end
      }
    when "tag_expr", "tag_expr_v2", "object"
      case mode
      when "tag_expr"
        expr = expression["expr"]
      when "tag_expr_v2"
        expr = MiqExpression.new(expression["expr"]).to_ruby
      when "object"
        expr = expression.to_ruby
      end

      MiqPolicy.logger.debug("MIQ(condition-eval): Name: #{name}, Expression before substitution: [#{expr.gsub(/\n/, " ")}]")

      subst(expr, rec, inputs)

      MiqPolicy.logger.debug("MIQ(condition-eval): Name: #{name}, Expression after substitution: [#{expr.gsub(/\n/, " ")}]")
      result = self.do_eval(expr)
      MiqPolicy.logger.info("MIQ(condition-eval): Name: #{name}, Expression evaluation result: [#{result}]")
    end
    result
  end

  def self.do_eval(expr)
    if expr =~ /^__start_ruby__\s?__start_context__\s?(.*)\s?__type__\s?(.*)\s?__end_context__\s?__start_script__\s?(.*)\s?__end_script__\s?__end_ruby__$/im
      context, col_type, script = [$1, $2, $3]
      context = MiqExpression.quote(context, col_type)
      result = SafeNamespace.eval_script(script, context)
      raise "Expected return value of true or false from ruby script but instead got result: [#{result.inspect}]" unless result.kind_of?(TrueClass) || result.kind_of?(FalseClass)
    else
      result = eval(expr) ? true : false
    end
    result
  end

  def self.subst(expr, rec, inputs)
    findexp = /<find>(.+?)<\/find>/im
    if expr =~ findexp
      expr = expr.gsub!(findexp) {|s| _subst_find(rec, inputs, $1.strip)}
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Find Expression after substitution: [#{expr}]")
    end

    # Make rec class act as miq taggable if not already since the substitution fully relies on virtual tags
    rec.class.acts_as_miq_taggable unless rec.respond_to?("tag_list") || rec.kind_of?(Hash)

    # <mode>/virtual/operating_system/product_name</mode>
    # <mode ref=host>/managed/environment/prod</mode>
    expr.gsub!(/<(value|exist|count|registry)([^>]*)>([^<]+)<\/(value|exist|count|registry)>/im) {|s| _subst(rec, inputs, $2.strip, $3.strip, $1.strip)}

    # <mode /virtual/operating_system/product_name />
    expr.gsub!(/<(value|exist|count|registry)([^>]+)\/>/im) {|s| _subst(rec, inputs, nil, $2.strip, $1.strip)}

    expr
  end

  def self._subst(rec, inputs, opts, tag, mode)
    ohash, ref, _object = self.options2hash(opts, rec)

    case mode.downcase
    when "exist"
      ref.nil? ? value = false : value = ref.is_tagged_with?(tag, :ns => "*")
    when "value"
      if ref.kind_of?(Hash)
        value = ref.fetch(tag, "")
      else
        ref.nil? ? value = "" : value = ref.tag_list(:ns => tag)
      end
      value = MiqExpression.quote(value, ohash[:type] || "string")
    when "count"
      ref.nil? ? value = 0 : value = ref.tag_list(:ns => tag).length
    when "registry"
      ref.nil? ? value = "" : value = self.registry_data(ref, tag, ohash)
      value = MiqExpression.quote(value, ohash[:type] || "string")
    end
    value
  end

  def self.collect_children(ref, methods)
    method = methods.shift

    list = ref.send(method)
    return [] if list.nil?

    result = []
    result = list if methods.empty?
    list = [list] unless list.is_a?(Array)
    list.each {|obj|
      result.concat(collect_children(obj, methods)) unless methods.empty?
    }
    result
  end

  def self._subst_find(rec, inputs, expr)
    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Find Expression before substitution: [#{expr}]")
    searchexp = /<search>(.+)<\/search>/im
    expr =~ searchexp
    search = $1
    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Search Expression before substitution: [#{search}]")

    listexp = /<value([^>]*)>(.+)<\/value>/im
    search =~ listexp
    opts, ref, object = self.options2hash($1, rec)
    methods = $2.split("/")
    methods.shift
    methods.shift
    attr = methods.pop
    l = collect_children(rec, methods)

    return false if l.empty?

    list = l.collect {|obj|
      value = MiqExpression.quote(obj.send(attr), opts[:type])
      value = value.gsub(/\\/, '\&\&') if value.kind_of?(String)
      e = search.gsub(/<value[^>]*>.+<\/value>/im, value.to_s)
      obj if self.do_eval(e)
    }.compact

    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Search Expression returned: [#{list.length}] records")

    checkexp = /<check([^>]*)>(.+)<\/check>/im

    expr =~ checkexp
    checkopts = $1.strip
    check = $2
    checkmode = checkopts.split("=").last.strip.downcase

    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression before substitution: [#{check}], options: [#{checkopts}]")

    if checkmode == "count"
      e = check.gsub(/<count>/i, list.length.to_s)
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression after substitution: [#{e}]")
      result = !!proc { $SAFE = 4; eval(e) }.call
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression result: [#{result}]")
      return result
    end

    return false if list.empty?

    check =~ /<value([^>]*)>(.+)<\/value>/im
    raw_opts = $1
    tag = $2
    checkattr = tag.split("/").last.strip

    result = true
    list.each {|obj|
      opts, ref, object = self.options2hash(raw_opts, obj)
      value = MiqExpression.quote(obj.send(checkattr), opts[:type])
      value = value.gsub(/\\/, '\&\&') if value.kind_of?(String)
      e = check.gsub(/<value[^>]*>.+<\/value>/im, value.to_s)
      MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression after substitution: [#{e}]")

      result = self.do_eval(e)

      return true if result && checkmode == "any"
      return false if !result && checkmode == "all"
    }
    MiqPolicy.logger.debug("MIQ(condition-_subst_find): Check Expression result: [#{result}]")
    result
  end

  def self.options2hash(opts, rec)
    ref = rec
    ohash = {}
    unless opts.blank?
      val = nil
      opts.split(",").each {|o|
        attr, val = o.split("=")
        ohash[attr.strip.downcase.to_sym] = val.strip.downcase
      }
      if ohash[:ref] != rec.class.to_s.downcase
        ref = rec.send(val) if val && rec.respond_to?(val)
      end

      if ohash[:object]
        object = val.to_sym
        ref = inputs[object]
      end
    end
    return ohash, ref, object
  end

  def self.registry_data(ref, name, ohash)
    # <registry>HKLM\Software\Microsoft\Windows\CurrentVersion\explorer\Shell Folders\Common AppData</registry> == 'C:\Documents and Settings\All Users\Application Data'
    # <registry>HKLM\Software\Microsoft\Windows\CurrentVersion\explorer\Shell Folders : Common AppData</registry> == 'C:\Documents and Settings\All Users\Application Data'
    return nil unless ref.respond_to?("registry_items")
    if ohash[:key_exists]
      return ref.registry_items.where("name LIKE ? ESCAPE ''", name + "%").exists?
    elsif ohash[:value_exists]
      rec = ref.registry_items.find_by_name(name)
      return rec ? true : false
    else
      rec = ref.registry_items.find_by_name(name)
    end
    return nil unless rec

    rec.data
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    return [ self.class.to_s => h ]
  end

  def self.import_from_hash(condition, options={})
    status = {:class => self.name, :description => condition["description"]}
    c = Condition.find_by_guid(condition["guid"])
    msg_pfx = "Importing Condition: guid=[#{condition["guid"]}] description=[#{condition["description"]}]"

    if c.nil?
      c = Condition.new(condition)
      status[:status] = :add
    else
      status[:old_description] = c.description
      c.attributes = condition
      status[:status] = :update
    end

    unless c.valid?
      status[:status]   = :conflict
      status[:messages] = c.errors.full_messages
    end

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    unless options[:preview] == true
      MiqPolicy.logger.info(msg)
      c.save!
    else
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    end

    return c, status
  end

  protected

  module SafeNamespace
    def self.eval_script(script, context)
      log_prefix = "MIQ(SafeNamespace.eval_script)"
      $log.debug("#{log_prefix} Context: [#{context}], Class: [#{context.class.name}]")
      $log.debug("#{log_prefix} Script:\n#{script}")
      begin
        t = Thread.new do
          script = "$SAFE = 3\n#{script}"
          Thread.current["result"] = _eval(context, script)
        end
        to = 20 # allow 20 seconds for script to complete
        Timeout::timeout(to) { t.join }
      rescue TimeoutError => err
        t.exit
        $log.error  "#{log_prefix} The following error occurred during ruby evaluation"
        $log.error  "#{log_prefix}   #{err.class}: #{err.message}"
        raise "Ruby script timed out after #{to} seconds"
      rescue Exception => err
        $log.error  "#{log_prefix} The following error occurred during ruby evaluation"
        $log.error  "#{log_prefix}   #{err.class}: #{err.message}"
        raise "Ruby script raised error [#{err.message}]"
      ensure
        (t["log"] || []).each {|m| $log.info("#{log_prefix} #{m}")} unless t.nil?
      end
      return t["result"]
    end

    def self._eval(context, script)
      eval(script)
    end

    def self.log(msg)
      Thread.current["log"] ||= []
      Thread.current["log"] << "[#{Time.now.utc.iso8601(6).chop}] #{msg}"
    end
  end
end # class Condition
