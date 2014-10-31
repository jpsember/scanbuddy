#!/usr/bin/env ruby

require 'js_base'

class ScanBuddyApp

  TMP_TEST_DIR = '_tmp_'
  IMG_EXT = Set.new ['jpg','jpeg','png','gif']
  SKIP_FILE_PATTERNS = [/^#{TMP_TEST_DIR}$/,/^\.DS_Store$/,/^\.$/,/^\.\.$/]
  JPEG_FILE_PATTERN = /^.+\.jpe?g$/

  def initialize
  end

  def pic_arg(pic, name)
    cmd = "sips -g #{name} \"#{pic}\""
    res,_ = scall(cmd)
    arg = res.split.last
    arg.to_i
  end

  def resize(pic)
    w_max = (@dpi * 8.5).to_i
    h_max = @dpi * 11

    w = pic_arg(pic,"pixelWidth")
    h = pic_arg(pic,"pixelHeight")

    if w <= w_max and h <= h_max
      puts("Not resizing #{pic}, dimensions (#{w},#{h}) not greater than max #{w_max},#{h_max}") if @verbose
      return
    end

    puts("Resizing, dimensions (#{w},#{h}) greater than max #{w_max},#{h_max}") if @verbose

    max_dim = [w_max,h_max].max
    cmd = "sips --resampleHeightWidthMax #{max_dim} \"#{pic}\""
    puts("#{cmd}") if @verbose
    scall(cmd)
  end

  def proc_dir(dirname)
    fl = Dir.entries(dirname)
    fl.each do |x|
      next if x == '.' or x == '..'
      y = File.join(dirname,x)
      if File.directory?(y)
        proc_dir(y)
      else
        ext = File.extname(x).downcase
        if ext.size > 0
          ext = ext[1..-1]
        end
        next if not IMG_EXT.member?(ext)
        resize(y)
      end
    end
  end

  def run(argv = nil)
    argv ||= ARGV
    p = Trollop::Parser.new do
      opt :maxdpi, "maximum dots per inch", :default => 300
      opt :verbose, "verbose operation"
      opt :dir, "directory to process", :type => :string
      opt :testtmp, "use test temp directory"
      opt :quality, "JPEG image quality", :default => 70
      opt :grayscale, "convert to grayscale", :default => false
      opt :overwrite, "overwrite existing output file"
      opt :stacktrace, "show stack trace if error"
      opt :maxsize, "maximum size in Mb", :default => 25 # GMail attachment limit
    end

    options = Trollop::with_standard_exception_handling p do
      p.parse(argv)
    end

    begin

      @verbose = options[:verbose]
      @dpi = options[:maxdpi]
      fail("bad argument") if @dpi < 40 || @dpi > 1200
      fail("missing directory") if !options[:dir]
      @dir = File.absolute_path(options[:dir])
      @test_tmp_dir = options[:testtmp]
      @quality = options[:quality]
      @grayscale = options[:grayscale]
      @overwrite = options[:overwrite]
      @max_size_limit = options[:maxsize]

      examine_dir
      construct_input_files
      construct_temp_dir
      convert_input_files
      build_output_pdf

      remove_temp_dir
      return 0
    rescue Exception => e
      raise e if options[:stacktrace]
      puts "*** " + e.message
      return 1
    end

  end

  def examine_dir
    fail("No such directory: #{@dir}") if !File.directory?(@dir)
    base_name = File.basename(@dir)
    @output_pdf = File.join(File.dirname(@dir),"#{base_name}.pdf")
    fail("Output file already exists: #{@output_pdf}") if !@overwrite && File.exist?(@output_pdf)
  end

  def construct_input_files
    @inp_files = []
    Dir.entries(@dir).each do |f|
      match = false
      SKIP_FILE_PATTERNS.each{|pat| match ||= (pat =~ f)}
      next if match

      fail("Unexpected file '#{f}' in directory #{@dir}") if f !~ JPEG_FILE_PATTERN
      @inp_files << f
    end


    # Sort input files
    @inp_files.sort! do |a,b|
      ap = file_elements(a)
      bp = file_elements(b)
      result = ap[0] <=> bp[0]
      if result == 0
        result = ap[1] <=> bp[1]
      end
      result
    end

    puts "inp_files: #{@inp_files}" if @verbose
  end

  SUFFIX_EXP = /^(.+)(\d+).jpe?g$/
  SUFFIX_NONE_EXP = /^(.+).jpe?g$/

  def file_elements(s)
    m = SUFFIX_EXP.match(s)
    if m
      [m[1],m[2].to_i]
    else
      m = SUFFIX_NONE_EXP.match(s)
      fail("unexpected arg: #{s}") if !m
      [m[1],-1]
    end
  end

  def construct_temp_dir
    require 'tmpdir'
    if @test_tmp_dir
      @tmp_dir = File.join(@dir,"_tmp_")
      if File.directory?(@tmp_dir)
        FileUtils.remove_dir(@tmp_dir)
      end
      Dir.mkdir(@tmp_dir)
    else
      @tmp_dir = Dir.mktmpdir()
    end
    fail("Could not create temp dir") if !File.directory?(@tmp_dir)
  end

  def remove_temp_dir
    if !@test_tmp_dir && @tmp_dir && File.directory?(@tmp_dir)
         FileUtils.remove_dir(@tmp_dir)
    end
  end

  def convert_input_files
    file_num = 0
    @cvt_files = []
    @inp_files.each do |f|
      pic_orig = File.join(@dir,f)
      pic_dest = File.join(@tmp_dir,file_num.to_s+".jpeg")
      file_num += 1

      FileUtils.cp(pic_orig,pic_dest)

      resize(pic_dest)
      @cvt_files << pic_dest
    end
  end

  def build_output_pdf
    cmd = "convert -quality #{@quality}"
    cmd << ' -colorspace gray' if @grayscale
    @cvt_files.each{|f| cmd << " \"#{f}\""}
    cmd << " \"#{@output_pdf}\""
    FileUtils.rm(@output_pdf) if @overwrite && File.exist?(@output_pdf)

    puts("#{cmd}") if @verbose
    scall(cmd)

    file_size =  File.size(@output_pdf)
    if (file_size / (1024*1024)) >= @max_size_limit
      fail("Output file #{@output_pdf} size #{file_size} exceeds limit of #@max_size_limit Mb")
    end
  end

end


if __FILE__ == $0
  ScanBuddyApp.new.run()
end
