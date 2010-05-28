#!/usr/bin/env ruby
require 'yaml'
require 'fileutils'
require 'digest/md5'

# initialize
config = YAML::load(File.open('svn-easy-backup.yaml'))
config[:svnadmin] ||= `which svnadmin`
config[:svnlook] ||= `which svnlook`
config[:repositories] ||= {}
config[:verbose] ||= false

svn_opts = "-q" if config[:verbose] != true

# sanity checks
unless File.exist?(config[:svn_root])
  puts "svn root doesn't exist"
  exit(-1)
end
FileUtils.mkdir_p config[:svn_backup]

# find repositories
root = Dir.new config[:svn_root]
repositories ||= []
root.each do |entry|
  repositories << entry unless entry == '.' or entry == '..'
end

# dump the repositories
repositories.sort!.each do |repository|
  config[:repositories][repository.to_sym] ||= {}
  backup_file = File.join(config[:svn_backup], "#{repository}.dumpfile")
  repository_path = File.join(config[:svn_root], repository)
  youngest = 0

  puts "** Inspecting #{repository_path}" if config[:verbose]

  # have we seen this before? If so, check integrity, dump incremental
  if File.exist?(backup_file) and config[:repositories][repository.to_sym][:md5]
    if config[:repositories][repository.to_sym][:md5] != Digest::MD5.hexdigest(File.read(backup_file))
      STDERR.puts "[!] Refusing to backup repository \"#{repository_path}\""
      STDERR.puts "[!] Previous backup \"#{backup_file}\" failed integrity check"
      next
    end

    # dump incremental
    last_revision = config[:repositories][repository.to_sym][:youngest]
    youngest = `#{config[:svnlook]} youngest #{repository_path}`.chomp.to_i
    if youngest > last_revision
      puts "** Dumping incremental revision #{last_revision + 1} to revision #{youngest}" if config[:verbose]
      `#{config[:svnadmin]} dump #{svn_opts} -r #{last_revision + 1}:#{youngest} --incremental #{repository_path} >> #{backup_file}`
      
    end
  else
    # full backup
    youngest = `#{config[:svnlook]} youngest #{repository_path}`.chomp.to_i
    puts "Dumping full backup to revision #{youngest}" if config[:verbose]
    `#{config[:svnadmin]} dump #{svn_opts} -r 0:#{youngest} #{repository_path} > #{backup_file}`
  end

  # save for next time
  config[:repositories][repository.to_sym][:md5] = Digest::MD5.hexdigest(File.read(backup_file))
  config[:repositories][repository.to_sym][:youngest] = youngest
end

config_file = File.open('svn-easy-backup.yaml', 'w')
config_file.write(config.to_yaml)
