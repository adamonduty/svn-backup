# svn-backup

svn-backup is a simple tool meant to make backing up multiple subversion
repositories easy and efficient. Most of the tools that exist today are
overly complex, rely on specific svn backends or filesystems, create too
many unnecessary files, or otherwise don't fit my needs.

svn-backup generates portable subversion dumpfiles that can be loaded
into nearly any repository. It relies on the little-known fact that
incremental dumpfiles can simply be *appended* to an existing dumpfile.
svn-backup creates a full dumpfile on first run, and then continually
appends to that dumpfile. In this way, 100 subversion repositories will only
ever be contained within 100 dumpfiles, no matter how many times the backup
process is run. You'll never again have to waste time combining N files
*per repository* in just the right order to restore your backup.

This gives you the advantage of full backups at the smaller cost of an
incremental.

svn-backup will optionally compress your backups. Much like subversion
dumpfiles, distinct gzip files can be concatenated to form one continuous
compressed stream [1]. svn-backup utilizes this property to keep incremental
backups fast on large repositories by avoiding a complete gunzip/gzip cycle.

svn-backup maintains state from previous backups to ensure dumpfile
integrity. It will refuse to append to a dumpfile that doesn't match
the previously generated file, but will instead generate a full
backup. If the youngest repository revision hasn't changed, svn-backup won't
do anything.

The resulting dumpfiles can easily be backed up via tools such as rsync.
Because svn-backup only adds the differences between revisions to an
existing file, rsync will be very bandwidth efficient.

## Installation

Add this line to your application's Gemfile:

    gem 'svn-backup'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install svn-backup

## Configuration

svn-backup assumes that you have number of subversion repositories
located at a common root:

```
  /var/svn
    repository_1/
    repository_2/
    ...
    repository_n/
```

A sample configuration file (in YAML format) might look like this:

```
 ---
 :svn_root: /var/svn
 :svnadmin: /usr/bin/svnadmin
 :svnlook: /usr/bin/svnlook
 :svn_backup: /var/backup/svn
 :repository_state: /var/backup/repositories.yaml
 :repo_pattern: .
 :gzip: true
 :gzip_path: /bin/gzip
 :quiet: false
```

In this case, subversion repositories will be inspected at /var/svn, and the
resulting dumpfiles will be located at /var/backup/svn.

As new repositories are found, state information about each one will appear in
the file specified by repository_state. Be sure to place this somewhere
consistent. If you delete it, svn-backup will generate full backups for every
repository.

## Usage

```
 Usage: svn-backup [options]
    -h, --help                       Usage information
    -q, --quiet                      Output less status information
    -c, --config FILE                Config file
    -v, --version                    Version
```

## Restoration

svn-backup generates simple subversion dumpfiles that can be loaded with
svnadmin.

Step 1: Create an empty repository
```
 svnadmin create /var/svn/repository_1
```
Step 2: Load the dumpfile
```
 svnadmin load /var/svn/repository_1 < repository_1.dumpfile
```
Step 3: There is no step 3!

A simple bash command can load all repositories at once:
```
 find . -type f -name "*.dumpfile" | while read i; do repository_name=`basename "$i" .dumpfile`; svnadmin create "$repository_name" && svnadmin load "$repository_name" < "$i"; done
```
Or, if gzipped:
```
 find . -type f -name "*.dumpfile.gz" | while read i; do repository_name=`basename "$i" .dumpfile.gz`; svnadmin create "$repository_name" && zcat "$i" | svnadmin load "$repository_name"; done
```
## Upgrade

Please note that upgrading from 0.1.x to 0.2.x will cause a full backup
of every repository due to differing state information in repositories.yaml.

## License
svn-backup is copyright 2010 Adam Lamar and distributed under the terms of
the GNU General Public License (GPL).  See the LICENSE file for further
information.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

# References

[1] http://www.gzip.org/zlib/rfc-gzip.html#file-format

