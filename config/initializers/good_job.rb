GoodJob::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
  ActiveSupport::SecurityUtils.secure_compare(Rails.application.credentials.good_job_username, username) &&
    ActiveSupport::SecurityUtils.secure_compare(Rails.application.credentials.good_job_password, password)
end

Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    daily_update: {
      cron: '0 7 * * *',
      class: "ImportJob",
      kwargs: {}
    }
  }
  config.good_job.queues = "default:1; bgg_data_import:1; image_attach:10; image_analysis:2"
end
