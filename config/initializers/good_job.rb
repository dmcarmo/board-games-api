GoodJob::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(Rails.application.credentials.good_job_username, username) &&
    ActiveSupport::SecurityUtils.secure_compare(Rails.application.credentials.good_job_password, password)
end

Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    weekly_on_mondays: {
      cron: '0 8 * * 1',
      class: "ImportJob"
    }
  }
end
