# Script to run the backup
# Created Shelekhov Dmitry

# Loading of required modules
require 'mail'
require 'yaml'
require 'logger'
require 'net/scp'

# Error classes
class BackupError < StandardError
end

# Create log file and variable for logging
@logger = Logger.new('../log/logfile.log')

# Reading config file
config = YAML.safe_load(open('config.yml'))

# Creating a file name
temp = "../tmp/#{Time.now.to_s.split(' +').first.gsub(/[\s,\:]/, '-')}.sql"

# Configuration mail
Mail.defaults do
  delivery_method :smtp, address: config['email']['address'], port: 25
end

# Local backup database
def local_backup(temp_path, config)
  `pg_dump -U #{config['user']} #{config['name']} -c -f #{temp_path}`
  error_msg = 'Temporary file is not created'
  raise BackupError, error_msg unless File.exist?(temp_path)
  @logger.info 'The backup is created in a temporary directory'
end

# Transfer the backup file to the backup server
def recive_backup(temp_path, config)
  options = { password: config['password'], non_interactive: true }
  Net::SCP.start(config['address'], config['user'], options) do |scp|
    scp.upload!(temp_path, config['backup_path'])
    @logger.info do
      "Backup uploaded to #{config['address']}, path #{config['backup_path']}
      ".delete("\n")
    end
    File.delete(temp_path)
    @logger.info "Temporary file deleted from #{temp_path}"
  end
end

# Creating an e-mail message
def create_message
  @logger.info 'E-mail sending...'
  file = File.open('../log/logfile.log', &:read)
  lines = file.split(/[\n]/)
  message = lines.find_all { |i| i.include?(Time.now.to_s.split(' ').first) }
  message.join("\n")
end

# Sending an email message
def send_mail(config, message)
  mail = Mail.new do
    from     config['from']
    to       config['to']
    subject  config['subject']
    body     message
  end
  mail.deliver!
rescue => error
  @logger.error error.message
end

# Running the script
begin
  local_backup(temp, config['database'])
  recive_backup(temp, config['server'])
rescue => error
  @logger.error error.message
ensure
  send_mail(config['email'], create_message)
end
