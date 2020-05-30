# coding: utf-8
# frozen_string_literal: true

require 'pathname'

module ColorLS
  module Git
    def self.status_and_lsfiles(repo_path)
      prefix = git_prefix(repo_path)

      return [nil,nil] unless $CHILD_STATUS.success?

      prefix = Pathname.new(prefix.chomp)

      git_status = Hash.new { |hash, key| hash[key] = Set.new }

      git_subdir_status(repo_path) do |output|
        while (status_line = output.gets "\x0")
          mode, file = status_line.chomp("\x0").split(' ', 2)

          path = Pathname.new(file).relative_path_from(prefix)

          git_status[path.descend.first.cleanpath.to_s].add(mode)

          # skip the next \x0 separated original path for renames, issue #185
          output.gets("\x0") if mode.start_with? 'R'
        end
      end
      warn "git status failed in #{repo_path}" unless $CHILD_STATUS.success?

      git_lsfiles = []

      git_ls_files(repo_path) do |output|
        while (status_line = output.gets "\x0")
          file = status_line.chomp("\x0")

          path = Pathname.new(file) #.relative_path_from(prefix)

          git_lsfiles.append(path)
        end
      end
      warn "git ls-files failed in #{repo_path}" unless $CHILD_STATUS.success?

      [git_status, git_lsfiles]
    end

    def self.colored_status_symbols(modes, colors)
      if modes.empty?
        return '  ✓ '
               .encode(Encoding.default_external, undef: :replace, replace: '=')
               .colorize(colors[:unchanged])
      end

      # remove "ignored" flag unless it's the only flag
      if modes.count >= 2 and modes.include?("!!") then
        modes.keep_if { |v| v != "!!" }
      end

      modes = modes.to_a.join.uniq.rjust(3).ljust(4)

      modes
        .gsub('?', '?'.colorize(colors[:untracked]))
        .gsub('A', 'A'.colorize(colors[:addition]))
        .gsub('M', 'M'.colorize(colors[:modification]))
        .gsub('D', 'D'.colorize(colors[:deletion]))
        .gsub('!', '.'.colorize(colors[:ignored]))
    end

    class << self
      private

      def git_prefix(repo_path)
        IO.popen(['git', '-C', repo_path, 'rev-parse', '--show-prefix'], err: :close, &:gets)
      end

      def git_subdir_status(repo_path)
        yield IO.popen(
          ['git', '-C', repo_path, 'status', '--porcelain', '-z', '-unormal', '--ignored', '.'],
          external_encoding: Encoding::ASCII_8BIT
        )
      end

      def git_ls_files(repo_path)
        yield IO.popen(
          ['git', '-C', repo_path, 'ls-files', '-z', '.'],
          external_encoding: Encoding::ASCII_8BIT
        )
      end
    end
  end
end
