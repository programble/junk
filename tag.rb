#!/usr/bin/env ruby

require 'set'

tags = ARGV.select {|x| x[0] == '+' }
files = ARGV - tags

if tags.empty? && files.empty? # List untagged files
  tags = Dir.entries('.').select {|x| x[0] == '+' && File.directory?(x) }
  files = Dir.entries('.').select {|x| File.file?(x) }
  tagged_files = Set.new
  tags.each {|tag| tagged_files.merge(Dir.entries(tag)) }
  puts files - tagged_files.to_a
elsif files.empty? # List tagged files
  tags.each do |tag|
    if File.directory?(tag)
      files << Dir.entries(tag).select do |x|
        if x[0] == '.'
          false
        elsif !File.symlink?(File.join(tag, x))
          STDERR.puts "warning: non-symlink file #{tag}/#{x}"
          false
        elsif !File.file?(x)
          STDERR.puts "warning: tagged file does not exist #{tag}/#{x}"
          false
        else
          true
        end
      end
    end
  end
  puts files.reduce(:&)
elsif tags.empty? # List file tags
  tags = Dir.entries('.').select {|x| x[0] == '+' && File.directory?(x) }
  files.each do |file|
    unless File.file?(file)
      STDERR.puts "warning: file does not exist #{file}"
      next
    end
    file_tags = tags.select {|tag| File.symlink?(File.join(tag, file)) }
    puts "#{file} #{file_tags.join(' ')}"
  end
else # Apply tags to files
  tags.each {|tag| Dir.mkdir(tag) unless File.directory?(tag) }
  files.each do |file|
    unless File.file?(file)
      STDERR.puts "warning: file does not exist #{file}"
      next
    end
    tags.each {|tag| File.symlink(File.join('..', file), File.join(tag, file)) unless File.symlink?(File.join(tag, file)) }
  end
end
