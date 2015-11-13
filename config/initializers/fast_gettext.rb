old_debug, $DEBUG = $DEBUG, nil
begin
  # The `gettext` gem unreasonably assumes that anyone with $DEBUG
  # enabled must want a flood of racc/yydebug output. As we're actually
  # trying to debug something other than their parser, we need to
  # temporarily force it off while we load stuff.
  Vmdb::FastGettextHelper.register_locales
  gettext_options = %w(--sort-by-msgid --location --no-wrap)
  Rails.application.config.gettext_i18n_rails.msgmerge = gettext_options
  Rails.application.config.gettext_i18n_rails.xgettext = gettext_options + ["--add-comments=TRANSLATORS"]

  unless Rails.env.test?
    db_file  = Rails.root.join("config", "vmdb.yml.db")
    template = Rails.root.join("config", "vmdb.tmpl.yml")
    config_file = File.exist?(db_file) ? db_file : template
    if YAML.load(File.read(config_file)).fetch_path(:ui, :mark_translated_strings)
      include Vmdb::Gettext::Debug
    end
  end
ensure
  $DEBUG = old_debug
end
