# typed: true
# frozen_string_literal: true

require_relative './archive'

class BP::Store
  def initialize
    @archives =
      IO.popen(%w[tarsnap --list-archives])
        .readlines
        .map(&:chomp)
        .map(&BP::Archive.method(:new))
  end

  def print
    longest_name = @archives.map(&:name).max_by(&:length)
    @archives.group_by(&:name).to_a.sort_by { |_, archives|
      archives.map(&:date).max
    }.each do |name, archives|
      ver_str = archives.map(&:date).sort.map { |d| d.strftime('%Y-%m-%d') }.join(', ')
      puts "#{name.ljust(longest_name.length)}\t#{ver_str}"
    end
  end

  def self.add(options)
    date_string = Date.today().strftime('%Y-%m-%d')

    options[:files]
      .map(&File.method(:expand_path))
      .map { |file|
        unless File.file?(file) || File.directory?(file)
          abort "'#{file}' is not a regular file or directory"
        end

        basename = File.basename(file)
        clean_basename = basename.gsub('-', '_')

        [
          File.dirname(file),
          [
            'tarsnap',
            '-c',
            '-f',
            "#{date_string}_#{clean_basename}",
            basename
          ]
        ]
      }.each do |dir, cmd|
        Dir.chdir dir do
          if options[:dry_run]
            p [dir, cmd]
          else
            system(*cmd)
          end
        end
      end

    new().drop_old(options) if options[:drop_old]
  end

  def get(options)
    options[:get].map { |archive_to_get|
      versions = @archives.filter { |archive| archive.name == archive_to_get }
      selected_version =
        if options[:version]
          versions.find { |archive|
            archive.date.strftime('%Y-%m-%d') == options[:version]
          }
        else
          versions.max_by(&:date)
        end

      unless selected_version
        msg = "Archive '#{archive_to_get}'"
        msg << " of version #{options[:version]}" if options[:version]
        msg << ' does not exist'
        warn msg
      end

      selected_version
    }.compact.map(&:extract_cmd).each do |cmd|
      if options[:dry_run]
        p cmd
      else
        system(*cmd)
      end
    end
  end

  def drop_old(options)
    names_to_drop = options[:files].map { |f| File.basename(f).gsub('-', '_') }

    @archives
      .filter { |archive| names_to_drop.empty? || names_to_drop.include?(archive.name) }
      .group_by(&:name)
      .map { |name, archives|
        (*old_archives, latest) = archives.sort_by(&:date)
        [name, old_archives, latest]
      }.reject { |_name, old_archives, _latest| old_archives.empty? }
      .each do |name, old_archives, latest|
        versions_to_drop =
          old_archives
          .map(&:date)
          .map { |d| d.strftime('%Y-%m-%d') }
          .join(', ')

        puts "Archive '#{name}'"
        puts "\tversions that are going to be removed: #{versions_to_drop}"
        puts "\tremaining version: #{latest.date.strftime('%Y-%m-%d')}"

        old_archives.map(&:drop_cmd).each do |cmd|
          if options[:dry_run]
            p cmd
          else
            system(*cmd)
          end
        end
      end
  end
end
