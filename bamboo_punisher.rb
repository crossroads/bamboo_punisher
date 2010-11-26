#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'net/https'
require 'yaml'
require 'nokogiri'
require 'open-uri'

File_Last_Fail = File.join(File.dirname(__FILE__), 'last_fail.yml')
File_Config    = File.join(File.dirname(__FILE__), 'config', 'config.yml')
ResetTimes     = {:down => 4000,
                  :left => 9000}
MaxPerRotation = 3000

BambooServerSSH = "root@integration"

class BuildPunisher
  attr_accessor :config
  
  def initialize
    @config = YAML.load_file(File_Config)
  end

  def retrieve_xml
    puts "=== So whos been naughty then? ..."
    url = URI.parse(@config["bamboo"]["failed_rss_url"])
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(url.path + "?" + url.query)
    req.basic_auth @config["bamboo"]["username"], @config["bamboo"]["password"]
    res = http.request(req)
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      return Nokogiri::XML.parse(res.body)
    else
      return nil
    end
  end
  
  def reset
    puts "=== Resetting launcher rotation..."
    turn_down(ResetTimes[:down])
    turn_left(ResetTimes[:left])
  end
  
  def fire_at_and_reset(right_time, up_time)
    puts "=== Aim..."
    turn_right(right_time)
    turn_up(up_time)
    puts "===== FIRE!!!"
    fire
    sleep 0.4
    reset
  end
  
  def turn_left(time); rotate("L", time); end
  def turn_right(time); rotate("R", time); end
  def turn_up(time); rotate("U", time); end
  def turn_down(time); rotate("D", time); end
  
  def rotate(direction, time)
    while time > 0
      if time > MaxPerRotation
        iteration_time = MaxPerRotation
      else
        iteration_time = time
      end
      Thread.new do
        system("USBMissileLauncherUtils -#{direction} -S #{iteration_time}")
      end
      sleep(iteration_time.to_f / 1000.0)
      time -= MaxPerRotation
    end
  end
  
  def fire
    Thread.new do
      system("USBMissileLauncherUtils -F")
    end
    sleep 2.5
  end

end

@bp = BuildPunisher.new

@last_fail = YAML.load_file(File_Last_Fail) || {} rescue {}

failed_builds = @bp.retrieve_xml

last_fail = failed_builds.xpath("//item").first

last_fail_time = Time.parse(last_fail.xpath("pubDate").text)
last_fail_desc = last_fail.xpath("description").text

last_fail.xpath("link").text =~ /\/bamboo\/browse\/([A-Z-]+)-([0-9]+)$/
build_plan   = $1
build_number = $2


if @last_fail[:time] != last_fail_time
  
  # Start up webcam recording process, delete existing file first.
  File.delete("/opt/scripts/bamboo_punisher/missile_log.avi") if File.exist?("/opt/scripts/bamboo_punisher/missile_log.avi")
  webcam = Thread.new do
    system("mencoder tv:// -tv driver=v4l2:width=320:height=240:fps=30:device=/dev/video0 -nosound -ovc lavc -lavcopts vcodec=mpeg4:vbitrate=1800:vhq:keyint=250 -o /opt/scripts/bamboo_punisher/missile_log.avi 2>&1 > /dev/null")
  end
  
  puts "===== The build has failed!! Somebody gonna getta hurt real bad..."  
  @bp.reset
  @bp.config["users"].each do |name, positions|
    if last_fail_desc.include?(name)
      puts "===== Oh no! #{name} broke the build! Watch out!!"
      @bp.fire_at_and_reset(positions["right"], positions["up"])
    end
  end

  puts "===== Punishment has been served!!"
  
  File.open(File_Last_Fail, 'w') {|f| f.puts({:time => last_fail_time}.to_yaml) }
  
  # Stop recording.
  webcam.kill
  system("pkill mencoder")
  
  # Copy the webcam video as a build 'punishments' artifact
  # webcam_videofile = "/opt/scripts/bamboo_punisher/missile_log.avi"
  # bamboo_punishments_path = "/var/bamboo/xml-data/builds/#{build_plan}/download-data/artifacts/build-#{build_number}/Punishments/"
  # system("sudo su ndbroadbent -c \"rsync -ave ssh #{webcam_videofile} #{BambooServerSSH}:#{bamboo_punishments_path}\"")
else
  puts "===== Phew, no-one needs punishing... FOR NOW!"
end
