# The `gettext` gem unreasonably assumes that anyone with $DEBUG
# enabled must want a flood of racc/yydebug output. As we're actually
# trying to debug something other than their parser, we need to
# temporarily force it off while we load stuff.
old_debug, $DEBUG = $DEBUG, nil
begin
  load_paths = Vmdb::Plugins.to_a.unshift(Rails).flat_map do |engine|
    Dir.glob(engine.root.join('locale', '*.yml'))
  end
  load_paths.sort_by! { |p| File.basename(p) } # consistently sort en_foo.yml *after* en.yml
  I18n.load_path += load_paths

  Vmdb::FastGettextHelper.register_locales
  Vmdb::FastGettextHelper.register_human_localenames
  gettext_options = %w(--sort-by-msgid --location --no-wrap)
  Rails.application.config.gettext_i18n_rails.msgmerge = gettext_options + ["--no-fuzzy-matching"]
  Rails.application.config.gettext_i18n_rails.xgettext = gettext_options + ["--add-comments=TRANSLATORS"]

  if !Rails.env.test? && !Rails.env.production? && Settings.ui.mark_translated_strings
    include Vmdb::Gettext::Debug
  end
ensure
  $DEBUG = old_debug
end
