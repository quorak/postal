require 'postal/config'

if Postal.config.general&.exception_url
  Sentry.init do |config|
    config.dsn = Postal.config.general.exception_url
    config.enabled_environments = ['production']
    if ENV['DEV_EXCEPTIONS']
      config.enabled_environments << 'development'
    end
    config.tags = {:process => ENV['PROC_NAME']}
  end
end
