class Dictionary
  FIXTURE_DIR  = File.join(Rails.root, "db/fixtures")
  FIXTURE_FILE = File.join(FIXTURE_DIR, "#{self.to_s.pluralize.underscore}.csv")

  def self.dict
    @dict ||= self.load
  end

  def self.load
    dictionary = {}

    skip_header = true
    File.open(FIXTURE_FILE, 'r').each_line do |line|
      if skip_header
        skip_header = false
        next
      end
      next if line.blank?
      next if line.starts_with?("#")

      typ, name, text, locale = line.chomp.split(',')
      dictionary[self.make_key(name.strip, locale.strip, typ.strip)] = text.strip
    end

    dictionary
  end

  def self.getfield(text, opts = {})
    t1, t2 = text.split("__")
    result = self.get(self.make_key(t1, opts[:locale], opts[:type]))
    if t1.include?(".") && !result
      result = self.get(self.make_key(t1.split(".").last, opts[:locale], opts[:type].to_s))
    end
    result += " (#{t2.titleize})" unless result.nil? || t2.nil?
    return result
  end

  def self.system_locale
    @system_locale ||= (ENV["LANG"] || "en").split(".").first.downcase.split("_").first
  end

  def self.gettext(text, opts = {})
    opts[:locale]   ||= self.system_locale
    opts[:type]     ||= :column
    opts[:notfound] ||= nil

    result = getfield(text, opts)
    if !result && opts[:locale].match("_")
      opts[:locale] = opts[:locale].split("_").first
      result = getfield(text, opts)
    end

    if result
      result
    else
      if opts[:notfound]
        if text.include?(".")
          table, col = text.split(".")
          col = col[2..-1] if col.starts_with?("v_") && opts[:notfound].to_sym == :titleize
          col.send(opts[:notfound])
        else
          text = text[2..-1] if text.starts_with?("v_") && opts[:notfound].to_sym == :titleize
          text.send(opts[:notfound])
        end
      else
        text
      end
    end
  end

  def self.get(key)
    dict[key]
  end

  def self.make_key(name, locale, typ)
    [name, locale, typ].join("-")
  end
end
