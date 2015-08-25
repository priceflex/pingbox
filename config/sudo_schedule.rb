# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
#
$current_path = "#{Dir.pwd}"

set :output, "#{$current_path}/log/sudo_cron_log.log"

every 1.day, :at => "1am" do
  # sync system clock.
  command "ntpdate ntp.ubuntu.com pool.ntp.org"
end

every :sunday, :at => "2am" do
  # remove cron_log file.
  command "rm -rf #{$current_path}/log/cron_log.log"

  # reboot the machine.
  command "/sbin/reboot"
end
