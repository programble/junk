#!/usr/bin/env ruby

require 'yaml'

if ARGV.empty?
  if File.file?('.suivant.yml')
    yaml = YAML.load_file('.suivant.yml')
    command = yaml[:command]
    last_file = yaml[:last_file]

    files = Dir["*#{File.extname(last_file)}"].sort
    next_file = files[files.find_index(last_file) + 1]
  else
    puts "usage: suivant <command> <file>"
    puts "       suivant"
    exit
  end
else
  command = ARGV[0..-2].join(' ')
  next_file = ARGV[-1]
end

unless next_file
  puts "error: no more files"
  exit 1
end

File.open('.suivant.yml', 'w') do |f|
  f.write(YAML.dump(:command => command, :last_file => next_file))
end

puts "#{command} #{next_file}"
exec(command, next_file)
