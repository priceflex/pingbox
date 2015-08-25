$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root

require 'yaml'
require 'uri'
require 'pry'
require 'net/http'
require "#{$pingbox_root}/lib/ping/ping"
require "#{$pingbox_root}/lib/pingbox/send_to_s3"

class SpeedTest

  attr_accessor :upload_speed, :download_speed

  def initialize
    @amazon_s3 = SendToS3.new
    upload_test
    download_test
    send_results
  rescue Exception => e
    puts "Error in speed-test: #{e.message}"
    e.backtrace.each { |m| puts "\tfrom #{m}" }
  end

  def upload_test
    file_size = File.size("#{$pingbox_root}/upload.file") / 1024.0 / 1024.0
    start_time = Time.now
    bucket_obj = @amazon_s3.upload_speed_test
    end_time = Time.now
    bucket_obj.delete
    @upload_speed = (file_size / (end_time - start_time)) * 8
  end

  def download_test
    start_time = Time.now
    system("wget https://pingbox-speedtest-us.s3.amazonaws.com/5mb-download.file -O #{$pingbox_root}/5mb-download.file")
    end_time = Time.now
    file_size = File.size("#{$pingbox_root}/5mb-download.file") / 1024.0 / 1024.0
    system("rm #{$pingbox_root}/5mb-download.file")
    @download_speed = (file_size / (end_time - start_time)) * 8
  end

  def send_results
    if File.exist?("#{$pingbox_root}/config/machine.yml") && File.exist?("#{$pingbox_root}/config/test_case.yml")
      test_case = YAML.load(File.open("#{$pingbox_root}/config/test_case.yml"))
      machine = YAML.load(File.open("#{$pingbox_root}/config/machine.yml"))
      url = Ping.env? == :production ? "ping.techrockstars.com" : "192.168.0.124:3000"
      machine_url = "http://#{url}/machine/#{machine[:machine_id]}"

      data = {
        :speed_data => {
          :upload_speed   => @upload_speed,
          :download_speed => @download_speed,
          :test_case_id   => test_case[:test_case_id],
          :machine_id     => machine[:machine_id],
          :time           => Time.now.to_i * 1000
        }
      }

      Net::HTTP.post_form(URI.parse("#{machine_url}/speed_test"), data)
      puts "Successfully sent speed-test data to #{machine_url}/speed_test"
    else 
      return puts "Machine/Test Case configuration files not found. Aborting speed test."
    end
  end
end

SpeedTest.new