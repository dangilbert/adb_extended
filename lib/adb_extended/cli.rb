require 'thor'
require 'terminal-table'
require 'adb_extended'
require 'yaml'
require 'fileutils'

$configuration_file_dir = File.expand_path("~/.adb_extended")

module AdbExtended
  class CLI < Thor
    include Thor::Actions

    desc "devices", "Lists the Android devices with a little more info"
    method_options :battery => :boolean, :select_device => :boolean
    def devices()
      devices = AdbExtended::Adb.devices

      table = Terminal::Table.new do |t|
        header_row = %w(# Model Serial)

        if options.battery?
          header_row.push('Battery')
        end

        t << header_row
        t << :separator
        devices.each_with_index {|value, index|
          row = [index + 1, value[:model], value[:serial]]

          if options.battery?
            battery_level = AdbExtended::Adb.battery(value[:serial]).gsub('level:', '')
            row.push(battery_level)
          end

          t.add_row row
        }
      end

      puts table

    end

    desc "ashell", "Lists the devices and allows you to choose one to run the shell on"
    def ashell
      serial = pick_device
      AdbExtended::Adb.shell(serial)
    end

    desc "login", "Allows entry of usernames and passwords and will inject it into the login screen of the selected device"
    method_options :all => :boolean
    def login()

      # Get the username/password
      # Show the list of existing usernames/passwords

      user_file_path = "#{$configuration_file_dir}/app_users.yml"

      create_config_file(user_file_path)

      users = YAML.load_file(user_file_path)

      unless users
        users = {}
      end

      table = Terminal::Table.new do |t|
        header_row = %w(# Username)

        t << header_row
        t << :separator
        if users.size > 0
          users.each_with_index {|(key, value), index|
            row = [index + 1, value[:username]]
            t.add_row row
          }
        end

        row = [users.size + 1, "Add new user"]
        t.add_row row
      end

      puts table

      accepted_inputs = *(1..users.size + 1).map {|i| i.to_s}
      index = ask("Select an account to login (1 - #{users.size + 1}):", :limited_to => accepted_inputs).to_i - 1
    
      if index > users.size - 1
        # Create new user and save it or overwrite existing user
        username = ask("Enter a username:")
        password = ask("Enter a password:")

        users[username] = {:username => username, :password => password}

        File.open(user_file_path, "w") { |file| file.write(users.to_yaml) }
        user = users[username]
      else
        user = users[users.keys[index]]
      end

      if options.all
        AdbExtended::Adb.enter_text(user[:username], false)
        AdbExtended::Adb.enter_text(user[:password], true)
      else
        device = pick_device
        AdbExtended::Adb.enter_text(user[:username], false, device)
        AdbExtended::Adb.enter_text(user[:password], true, device)
      end
    end

    desc "pidcat PACKAGE", "Lists the devices and allows you to choose one to run with pidcat"
    method_option :level, :default => 'd', :enum => %w(V D I W E F v d i w e f), :aliases => '-l'
    def pidcat(package = nil)
      serial = pick_device
      AdbExtended::Adb.pidcat(serial, options[:level], package)
    end

    desc "logcat PACKAGE", "Lists the devices and allows you to choose one to run with logcat"
    method_option :level, :default => 'D', :enum => %w(V D I W E F), :aliases => '-l'
    def logcat(package = nil)
      serial = pick_device
      AdbExtended::Adb.logcat(serial, options[:level], package)
    end

    desc "install PATH", "Installs the provided apk on the selected device"
    method_options :all => :boolean
    def install(path)
      if options.all
        AdbExtended::Adb.install(path)
        exit(0)
      end
      serial = pick_device
      AdbExtended::Adb.install(path, serial)
    end

    desc "uninstall PACKAGE", "Uninstalls the provided package on the selected device"
    method_options :all => :boolean
    def uninstall(package)
      if options.all
        AdbExtended::Adb.uninstall(package)
        exit(0)
      end
      serial = pick_device
      AdbExtended::Adb.uninstall(package, serial)
    end

    desc "screencap", "Takes a screenshot on the selected device (or all devices)"
    method_options :all => :boolean
    def screencap()
      if options.all
        AdbExtended::Adb.screenshot()
        exit(0)
      end
      serial = pick_device
      AdbExtended::Adb.screenshot(serial)
    end

    private

    # Returns the serial number of the chosen device
    def pick_device

      devices = AdbExtended::Adb.devices

      if devices.size == 0
        puts 'No devices found'
        exit 1
      end

      if devices.size == 1
        return devices[0][:serial]
      end

      table = Terminal::Table.new do |t|
        header_row = %w(# Model Serial)

        t << header_row
        t << :separator
        devices.each_with_index {|value, index|
          row = [index + 1, value[:model], value[:serial]]
          t.add_row row
        }
      end

      puts table

      accepted_inputs = *(1..devices.size).map {|i| i.to_s}
      index = ask("Select a device (1 - #{devices.size}):", :limited_to => accepted_inputs).to_i - 1
      devices[index][:serial]
    end

    def create_config_file(path)
      dirname = File.dirname(path)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end
      File.open(path, 'a+')
    end

  end
end