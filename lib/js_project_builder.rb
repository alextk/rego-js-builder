require 'yaml'

class JsProjectBuilder
  attr_reader :name, :description,
              :dist_file_name, :dist_file_path, :dist_min_file_path, :dist_pack_file_path,
              :js_files

  def initialize(options = {})
    @options = {
      :dist_dir => 'dist',
      :src_dir => 'src',
      :sass => false,
      :sass_dir => 'src/sass',
      :license_file => 'license.txt',
      :version_file_path => 'version.yml'
    }.update(options)

    @name = @options[:name]
    @description = @options[:description]
    @dist_file_name = @options[:file_name]
    @dist_file_path = File.join(dist_dir, dist_file_name)
    @dist_min_file_path = @dist_file_path.ext('min.js')
    @dist_pack_file_path = @dist_file_path.ext('pack.js')
    @js_files = @options[:js_files].collect{|name| File.join(self.src_dir, name)}

    @version_yml = YAML::load(File.open(@options[:version_file_path]))
  end

  def src_dir
    @options[:src_dir]
  end

  def dist_dir
    @options[:dist_dir]
  end

  def sass_dir
    @options[:sass_dir]
  end

  def sass?
    @options[:sass]
  end

  def license_file
    @options[:license_file]
  end

  def version
    @version_yml['version']
  end

  def build_number
    @version_yml['build_number']
  end

  def bump_version(type)
    index = {:major => 0, :minor => 1, :patch => 2}[type]

    arr = version.split('.').collect{|s| s.to_i }
    arr[index]+=1
    @version_yml['version'] = arr.join('.')
    
    write_version_file
    
    version
  end

  def bump_build_number
    @version_yml['build_number'] += 1
    @version_yml['built_at'] = Time.now.strftime('%a %m %b %Y %H:%M:%S')
    write_version_file
    build_number
  end

  # join given files into single target file.
  # if include_license_file is true (by default) then license file will be added to the head of the target file
  def join_files(target_file, files, include_license_file = true)
    files.insert(0, license_file) if include_license_file

    existing_files = files.existing
    if existing_files.length != files.length
      raise "ERROR: The following files are missing: \n#{files.select{|f| !existing_files.include?(f) }.join("\n")}"
    end

    File.open(target_file, 'w') do |f|
      files.each do |fname|
        f.puts File.read(fname)
      end
    end
  end


  private
  def write_version_file
    File.open(@options[:version_file_path], 'w'){|f| f.write(@version_yml.to_yaml) }
  end

end