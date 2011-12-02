require 'rake'
require 'rake/tasklib'

class JsProjectBuilder

  class Tasks < ::Rake::TaskLib
    attr_reader :project_builder

    def initialize(project_builder)
      @project_builder = project_builder
      define
    end

    private
    def define
      task :default => [:clobber, :pack]

      directory project_builder.dist_dir

      task :clobber do
        rm_r project_builder.dist_dir, :force => true
      end

      desc 'Prepare the project for build (destination directory and update licence file)'
      task :prepare => project_builder.dist_dir do
        File.open(project_builder.license_file, 'w+') do |f|
            license_tpl = File.read(File.join('build', project_builder.license_file.ext('.tpl.txt')))
            project_builder.bump_build_number
            f.puts license_tpl.interpolate(
              :project_name => project_builder.name,
              :project_description => project_builder.description,
              :project_version => project_builder.version,
              :build_number => project_builder.build_number,
              :date => Time.now.strftime('%d %b %Y %H:%M:%S')
            )
        end
      end

      desc 'Join all javascript files into one joined file with version and license at the head'
      task :js => :prepare do
        puts "Building single js file: #{project_builder.dist_file_name}"

        files = FileList[project_builder.js_files]
        project_builder.join_files(project_builder.dist_file_path, files)
      end

      desc 'Run JSHint checks on the joined javsacript file (runs via nodejs)'
      task :hint => :js do
        puts "Running JSHint on #{project_builder.dist_file_name} ..."
        sh "node build/tools/jshint-check.js #{project_builder.dist_file_path}" do |ok, output|
          ok or fail "Error running jshint on #{project_builder.dist_file_path}. \n #{output}"
        end
      end

      desc 'Compress js, remove all comments add copyright notice to the head of the file (runs via nodejs with uglify script)'
      task :min => :js do
        puts "Minifying: creating #{project_builder.dist_file_name.ext('min.js')}..."
        tmp_min_file = File.join(project_builder.dist_dir, 'tmp.min.js')
        sh "node build/tools/uglify.js --unsafe -o #{tmp_min_file} #{project_builder.dist_file_path}" do |ok, output|
          ok or fail "Error running uglify on #{project_builder.dist_file_path}. \n #{output}"
        end

        project_builder.join_files(project_builder.dist_min_file_path, FileList[tmp_min_file])
        File.delete(tmp_min_file)
      end
      
      desc 'Run rhino server and pack minified js file into even smaller size. add copyright notice at the start'
      task :pack => :min do
        pack_min_file = File.join(project_builder.dist_dir, 'tmp.min.js')

        puts "Packing: creating #{project_builder.dist_pack_file_path}..."
        sh "java -jar build/tools/rhino.jar build/tools/packer.js #{project_builder.dist_min_file_path} #{pack_min_file}" do |ok, output|
          ok or fail "Error packing #{project_builder.dist_min_file_path}. \n #{output}"
        end

        project_builder.join_files(project_builder.dist_pack_file_path, FileList[pack_min_file])
        File.delete(pack_min_file)
      end

      namespace :version do
        desc "Displays the current version"
        task :current do
          puts "Current version: #{project_builder.version} (build #{project_builder.build_number})"
        end

        namespace :bump do
          desc "Bump the major version by 1"
          task :major => 'version:current' do
            project_builder.bump_version(:major)
            puts "Updated version: #{project_builder.version}"
          end

          desc "Bump the a minor version by 1"
          task :minor => 'version:current' do
            project_builder.bump_version(:minor)
            puts "Updated version: #{project_builder.version}"
          end

          desc "Bump the patch version by 1"
          task :patch => 'version:current' do
            project_builder.bump_version(:patch)
            puts "Updated version: #{project_builder.version}"
          end

          desc 'Bump the build number by 1'
          task :build_number => 'version:current' do
            project_builder.bump_build_number
            puts "Updated build number: #{project_builder.build_number}"
          end
        end
      end

    end

  end

end