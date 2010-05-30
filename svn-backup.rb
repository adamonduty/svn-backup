#!/usr/bin/env ruby
require 'yaml'; require 'fileutils'; require 'digest/md5'; require 'optparse'

# parse options
verbose = nil
config_file = nil
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: svn-backup.rb [options]"
  opts.on('-h', '--help', 'Usage information') do
    puts opts
    exit
  end
  opts.on('-v', '--verbose', 'Output status information') { verbose = true }
  opts.on('-c', '--config FILE', 'Config file') { |file| config_file = file }
end
optparse.parse!

# initialize
config_file ||= 'svn-backup.yaml'
FileUtils.touch config_file
config = YAML::load(File.open(config_file))
config[:svnadmin] ||= `which svnadmin`
config[:svnlook] ||= `which svnlook`
config[:repository_state] ||= 'repositories.yaml'
config[:verbose] = verbose if verbose

FileUtils.mkdir_p config[:svn_backup]
FileUtils.touch config[:repository_state]
repository_state = YAML::load(File.open(config[:repository_state]))
repository_state ||= {}
repository_state[:repositories] ||= {}

# sanity checks
STDERR.puts "svn root doesn't exist" && exit(-1) unless File.exist? config[:svn_root]
STDERR.puts "couldn't find svnadmin or svnlook" && exit(-1) if !File.exist? config[:svnadmin] or !File.exist? config[:svnlook]
STDERR.puts "couldn't find gzip or gunzip" && exit(-1) if !File.exist? config[:gzip_path] or !File.exist? config[:gunzip_path]

# find repositories
root = Dir.new config[:svn_root]
repositories ||= []
root.each {|entry| repositories << entry unless entry == '.' or entry == '..' }

# dump the repositories
repositories.sort!.each do |repository|
  repository_state[:repositories][repository.to_sym] ||= {}
  backup_file = File.join(config[:svn_backup], "#{repository}.dumpfile")
  backup_file += '.gz' if config[:gzip]
  repository_path = File.join(config[:svn_root], repository)
  full_backup = false

  puts "[*] Inspecting #{repository_path}" if config[:verbose]
  last_revision = repository_state[:repositories][repository.to_sym][:youngest]
  youngest = `#{config[:svnlook]} youngest \"#{repository_path}\"`.chomp.to_i

  # have we seen this before?
  if youngest and last_revision and youngest > last_revision and File.exist?(backup_file) and repository_state[:repositories][repository.to_sym][:md5]
      # decompress, if needed
      if config[:gzip]
        puts "[*] Uncompressing #{backup_file}" if config[:verbose]
        `#{config[:gunzip_path]} \"#{backup_file}\"`
        backup_file.chomp! '.gz'
      end
   
      # check integrity
      puts "[*] Verifying integrity of #{backup_file}" if config[:verbose]
      if repository_state[:repositories][repository.to_sym][:md5] != Digest::MD5.hexdigest(File.read(backup_file))
        puts "[!] Refusing to perform incremental backup of repository \"#{repository_path}\""
        puts "[!] Previous backup \"#{backup_file}\" failed integrity check"
        repository_state[:repositories][repository.to_sym][:youngest] = nil
        redo
      end

      # dump incremental
      puts "[*] Dumping incremental revision #{last_revision + 1} to revision #{youngest}" if config[:verbose]
      `#{config[:svnadmin]} dump -q -r #{last_revision + 1}:#{youngest} --incremental \"#{repository_path}\" >> \"#{backup_file}\"`
  elsif (youngest and last_revision and youngest != last_revision) or (last_revision.nil?) or (!File.exist?(backup_file))
    # full backup
    full_backup = true
    backup_file.chomp! '.gz' if config[:gzip]
    puts "[*] Dumping full backup to revision #{youngest}" if config[:verbose]
    `#{config[:svnadmin]} dump -q -r 0:#{youngest} \"#{repository_path}\" > \"#{backup_file}\"`
  end 

  if (youngest and last_revision and youngest > last_revision) or (full_backup)
    # save for next time
    repository_state[:repositories][repository.to_sym][:md5] = Digest::MD5.hexdigest(File.read(backup_file))
    repository_state[:repositories][repository.to_sym][:youngest] = youngest

    # compress, if needed
    if config[:gzip]
      puts "[*] Compressing #{backup_file}" if config[:verbose]
      `#{config[:gzip_path]} -f \"#{backup_file}\"` 
    end
  end
end
repository_file = File.open(config[:repository_state], 'w')
repository_file.write(repository_state.to_yaml)