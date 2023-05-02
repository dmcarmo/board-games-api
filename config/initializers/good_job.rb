Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    weekly_on_mondays: {
      cron: '0 8 * * 1',
      class: "ImportJob"
    }
  }
end
