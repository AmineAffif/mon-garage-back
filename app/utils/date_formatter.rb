require 'date'
require 'i18n'

module DateFormatter
  I18n.available_locales = [:fr]
  I18n.locale = :fr

  # Charge les traductions françaises pour I18n
  I18n.backend.store_translations(:fr, {
    date: {
      formats: {
        default: "%d %B %Y",
        long: "%A %d %B %Y",
        short: "%d/%m/%Y"
      },
      day_names: %w(dimanche lundi mardi mercredi jeudi vendredi samedi),
      abbr_day_names: %w(dim lun mar mer jeu ven sam),
      month_names: [nil] + %w(janvier février mars avril mai juin juillet août septembre octobre novembre décembre),
      abbr_month_names: [nil] + %w(jan fév mar avr mai juin juil août sep oct nov déc)
    }
  })

  def self.format(date, format_type)
    # Convertit la chaîne en DateTime si nécessaire
    date = DateTime.parse(date) if date.is_a?(String)

    case format_type
    when :long
      date.strftime("%d %B %Y à %H:%M") # Exemple de format long
    when :short
      date.strftime("%d/%m/%Y")
    else
      date.to_s
    end
  end

end
