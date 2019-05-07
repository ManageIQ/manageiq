# The `gettext` gem unreasonably assumes that anyone with $DEBUG
# enabled must want a flood of racc/yydebug output. As we're actually
# trying to debug something other than their parser, we need to
# temporarily force it off while we load stuff.
old_debug, $DEBUG = $DEBUG, nil
begin
  # consistently sort en_foo.yml *after* en.yml; to_s because pathnames
  I18n.load_path += Dir[Rails.root.join('locale', '*.yml')].sort_by(&:to_s)
  Vmdb::FastGettextHelper.register_locales
  Vmdb::FastGettextHelper.register_human_localenames
  gettext_options = %w(--sort-by-msgid --location --no-wrap)
  Rails.application.config.gettext_i18n_rails.msgmerge = gettext_options + ["--no-fuzzy-matching"]
  Rails.application.config.gettext_i18n_rails.xgettext = gettext_options + ["--add-comments=TRANSLATORS"]

  if !Rails.env.test? && Settings.ui.mark_translated_strings
    include Vmdb::Gettext::Debug
  end
ensure
  $DEBUG = old_debug
end
