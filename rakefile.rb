# frozen_string_literal: true

desc 'Run rubocop'
task :lint do
  sh 'rubocop'
end
