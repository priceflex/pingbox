# This will make a 5MB File

#fallocate -l 5M upload.file

$pingbox_root = "#{File.dirname(__FILE__)}/../.." unless $pingbox_root

require 'yaml'
require 'net/http'
require 'uri'
require "ping/ping"
require "pingbox/send_to_s3"

class SpeedTest

  def initialize
    @upload_speed = 0.0
    @donlowad_speed = 0.0
    start_speed_test
    send_results
  rescue Exception => e
    puts "Cannot connect to s3: #{e.message}"
    e.backtrace.each { |m| puts "\tfrom #{m}" }
  end

  def start_speed_test
    file_size = File.size("#{$pingbox_root}/upload.file") / 1024.0 / 1024.0
    start_time = Time.now
    #file_name = "#{(rand * 100000).to_i}"
    #new_object = @bucket.objects.build("#{file_name}")
    #new_object.content = File.open("#{$pingbox_root}/upload.file")
    #new_object.save
    bucket_obj = SendToS3.upload_speed_test
    end_time = Time.now

    bucket_obj.delete

    @upload_speed = (file_size / (end_time - start_time)) * 8



    start_time = Time.now
    system("wget https://pingbox-speedtest-us.s3.amazonaws.com/5mb-download.file -O #{$pingbox_root}/5mb-download.file")
    end_time = Time.now
    system("rm #{$pingbox_root}/5mb-download.file")


    @download_speed = (file_size / (end_time - start_time)) * 8

  end

  def send_results
    if File.exist?("#{$pingbox_root}/config/machine.yml") && File.exist?("#{$pingbox_root}/config/test_case.yml")
      test = YAML.load(File.open("#{$pingbox_root}/config/test_case.yml"))
      machine = YAML.load(File.open("#{$pingbox_root}/config/machine.yml"))


      data = {
        :speed_data  => {
        :upload_speed => @upload_speed,
        :download_speed => @download_speed,
        :test_case_id => test[:test_case_id],
        :machine_id => machine[:machine_id],
        :time => Time.now.to_i * 1000
      }
      }
      begin
        if Ping.env? == :production
          postData = Net::HTTP.post_form(URI.parse("http://ping.techrockstars.com/machine/#{machine[:machine_id]}/speed_test"),data)
        else
          postData = Net::HTTP.post_form(URI.parse("http://192.168.0.124:3000/machine/#{machine[:machine_id]}/speed_test"),data)
        end

      rescue
        puts "Cannot send results"
      end

    end

  end


end

SpeedTest.new
