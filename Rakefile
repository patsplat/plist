##############################################################
# Copyright 2006, Ben Bleything.                             #
#                <ben@bleything.net>                         #
#                                                            #
# Based heavily on Geoffrey Grosenbach's Rakefile for gruff. #
# Includes whitespace-fixing code based on code from Typo.   #
#                                                            #
# Distributed under the MIT license.                         #
##############################################################

require 'fileutils'
require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

$:.unshift(File.dirname(__FILE__) + "/lib")
require 'plist'

PKG_NAME      = 'plist'
PKG_VERSION   = Plist::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

RUBYFORGE_PROJECT = "plist"
RUBYFORGE_USER    = "bleything"

TEST_FILES    = Dir.glob('test/test_*.rb').delete_if {|item| item.include?( "\.svn" ) }
RELEASE_FILES = [ "Rakefile", "README", "MIT-LICENSE" ] + TEST_FILES + Dir.glob( "lib/*" ).delete_if { |item| item.include?( "\.svn" ) }

task :default => [ :test ]
# Run the unit tests
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'test/test_*.rb'
  t.verbose = true
}

desc "Clean pkg and docs, remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_package ] do
  puts cmd = "find . -type f -name *.bak -delete"
  `#{cmd}`
end

desc "Strip trailing whitespace and fix newlines for all release files"
task :fix_whitespace => [ :clean ] do
  RELEASE_FILES.each do |filename|
    File.open(filename) do |file|
      newfile = ''
      needs_love = false

      file.readlines.each_with_index do |line, lineno|
        if line =~ /[ \t]+$/
          needs_love = true
          puts "#{filename}: trailing whitespace on line #{lineno}"
          line.gsub!(/[ \t]*$/, '')
        end

        if line.chomp == line
          needs_love = true
          puts "#{filename}: no newline on line #{lineno}"
          line << "\n"
        end

        newfile << line
      end

      if needs_love
        tempname = "#{filename}.new"

        File.open(tempname, 'w').write(newfile)
        File.chmod(File.stat(filename).mode, tempname)

        FileUtils.ln filename, "#{filename}.bak"
        FileUtils.ln tempname, filename, :force => true
        File.unlink(tempname)
      end
    end
  end
end

desc "Copy documentation to rubyforge"
task :update_rdoc => [ :rdoc ] do
  Rake::SshDirPublisher.new("#{RUBYFORGE_USER}@rubyforge.org", "/var/www/gforge-projects/#{RUBYFORGE_PROJECT}", "docs").upload
end

# Genereate the RDoc documentation
Rake::RDocTask.new { |rdoc|
  rdoc.rdoc_dir = 'docs'
  rdoc.title    = "PropertyList Generator -- plist"
  rdoc.options << '-SNmREADME'
  rdoc.template = "#{ENV['template']}.rb" if ENV['template']
  rdoc.rdoc_files.include('README', 'MIT-LICENSE', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/plist.rb')
}

# Create compressed packages
spec = Gem::Specification.new do |s|
  s.name    = PKG_NAME
  s.version = PKG_VERSION

  s.summary     = "Serialize your data as a Property List (aka plist)."
  s.description = <<-EOD
The Property List (plist) Generator allows you to serialize your data to Property Lists.  This is especially useful when writing system-level code for Mac OS X, but has other applications as well.  The basic Ruby datatypes (numbers, strings, symbols, dates/times, arrays, and hashes) can be natively converted to plist types, and other types are Marshal'ed into the plist <data> type.
EOD

  s.author   = "Ben Bleything"
  s.email    = "ben@bleything.net"
  s.homepage = "http://projects.bleything.net/plist"

  s.rubyforge_project = RUBYFORGE_PROJECT

  s.has_rdoc = true

  s.files      = RELEASE_FILES
  s.test_files = TEST_FILES

  s.autorequire = 'plist'
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end
