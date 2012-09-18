#!/usr/bin/env ruby
# svn-backup.rb - A fast, efficient way to backup multiple subversion repositories
# Copyright (C) 2010 Adam Lamar
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
require 'yaml'; require 'fileutils'; require 'digest/md5'; require 'optparse'
version = '0.1.1'

# parse options
quiet = debug = nil
config_file = nil
optparse = OptionParser.new do |opts|
  opts.version = version
  opts.banner = "Usage: svn-backup.rb [options]"
  opts.on('-h', '--help', 'Usage information') do
    puts opts
    exit
  end
  opts.on('-q', '--quiet', 'Output less status information') { quiet = true }
  opts.on('-d', '--debug', 'Output debug information') { debug = true }
  opts.on('-c', '--config FILE', 'Config file') { |file| config_file = file }
end
optparse.parse!

# initialize
config_file ||= 'svn-backup.yaml'
FileUtils.touch config_file
config = YAML::load(File.open(config_file))
config[:svnadmin] ||= IO.popen("which svnadmin") {}
config[:svnlook] ||= IO.popen("which svnlook") {}
config[:repository_state] ||= 'repositories.yaml'
config[:quiet] = quiet if quiet
config[:debug] = debug if debug

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
root.each {|entry| repositories << entry if !(entry == '.' or entry == '..') and (File.directory?(File.join(config[:svn_root], entry))) }

# dump the repositories
repositories.sort!.each do |repository|
  repository_state[:repositories][repository.to_sym] ||= {}
  backup_file = File.join(config[:svn_backup], "#{repository}.dumpfile")
  backup_file += '.gz' if config[:gzip]
  repository_path = File.join(config[:svn_root], repository)
  full_backup = false

  puts "[*] Inspecting #{repository_path}" unless config[:quiet]
  last_revision = repository_state[:repositories][repository.to_sym][:youngest]
  cmd = "#{config[:svnlook]} youngest \"#{repository_path}\""
  STDERR.puts cmd if config[:debug]
  youngest = IO.popen(cmd) { |f| f.read.chomp.to_i}

  # have we seen this before?
  if youngest and last_revision and youngest > last_revision and File.exist?(backup_file) and repository_state[:repositories][repository.to_sym][:md5]
    # check integrity
    puts "[*] Verifying integrity of #{backup_file}" unless config[:quiet]
    if repository_state[:repositories][repository.to_sym][:md5] != Digest::MD5.file(backup_file).to_s
      puts "[!] Refusing to perform incremental backup of repository \"#{repository_path}\""
      puts "[!] Previous backup \"#{backup_file}\" failed integrity check"
      repository_state[:repositories][repository.to_sym][:youngest] = nil
      redo
    end

    # dump incremental
    puts "[*] Dumping incremental revision #{last_revision + 1} to revision #{youngest}" unless config[:quiet]
    if config[:gzip]
      cmd = "#{config[:svnadmin]} dump -q -r #{last_revision + 1}:#{youngest} --incremental \"#{repository_path}\" | #{config[:gzip_path]} -c >> \"#{backup_file}\" 2> /dev/null"
    else
      cmd = "#{config[:svnadmin]} dump -q -r #{last_revision + 1}:#{youngest} --incremental \"#{repository_path}\" >> \"#{backup_file}\" 2> /dev/null"
    end
    STDERR.puts cmd if config[:debug]
    IO.popen(cmd) {}
  elsif (youngest and last_revision and youngest != last_revision) or (last_revision.nil?) or (!File.exist?(backup_file))
    # full backup
    full_backup = true
    puts "[*] Dumping full backup to revision #{youngest}" unless config[:quiet]
    cmd = ''
    if config[:gzip]
      cmd = "#{config[:svnadmin]} dump -q -r 0:#{youngest} \"#{repository_path}\" | #{config[:gzip_path]} -c >> \"#{backup_file}\" 2> /dev/null"
    else
      cmd = "#{config[:svnadmin]} dump -q -r 0:#{youngest} \"#{repository_path}\" >> \"#{backup_file}\" 2> /dev/null"
    end
    STDERR.puts cmd if config[:debug]
    IO.popen(cmd) {}
  end 

  if (youngest and last_revision and youngest > last_revision) or (full_backup)
    # save for next time
    repository_state[:repositories][repository.to_sym][:md5] = Digest::MD5.file(backup_file).to_s
    repository_state[:repositories][repository.to_sym][:youngest] = youngest
  end
end
repository_file = File.open(config[:repository_state], 'w')
repository_file.write(repository_state.to_yaml)
