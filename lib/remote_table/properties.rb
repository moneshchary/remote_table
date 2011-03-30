require 'uri'
class RemoteTable
  # Represents the properties of a RemoteTable, whether they are explicitly set by the user or inferred automatically.
  class Properties
    attr_reader :t
    def initialize(t)
      @t = t
    end
    
    # The parsed URI of the file to get.
    def uri
      return @uri if @uri.is_a?(::URI)
      @uri = ::URI.parse t.url
      if @uri.host == 'spreadsheets.google.com'
        @uri.query = 'output=csv&' + @uri.query.sub(/\&?output=.*?(\&|\z)/, '\1')
      end
      @uri
    end
    
    # The headers specified by the user
    def headers
      t.options['headers']
    end
    
    # The sheet specified by the user as a number or a string
    #
    # Default: 0
    def sheet
      t.options['sheet'] || 0
    end
    
    # Whether to keep blank rows
    #
    # Default: false
    def keep_blank_rows
      t.options['keep_blank_rows'] || false
    end
    
    # Form data to send in with the download request
    def form_data
      t.options['form_data']
    end
    
    # How many rows to skip
    #
    # Default: 0
    def skip
      t.options['skip'].to_i
    end
    
    # The encoding
    #
    # Default: "UTF-8"
    def encoding
      t.options['encoding'] || 'UTF-8'
    end
    
    # The delimiter
    #
    # Default: ","
    def delimiter
      t.options['delimiter'] || ','
    end
    
    # The XPath used to find rows
    def row_xpath
      t.options['row_xpath']
    end
    
    # The XPath used to find columns
    def column_xpath
      t.options['column_xpath']
    end
    
    # The compression type.
    #
    # Default: guessed from URI.
    #
    # Can be specified as: "gz", "zip", "bz2", "exe" (treated as "zip")
    def compression
      clue = if t.options['compression']
        t.options['compression'].to_s
      else
        ::File.extname uri.path
      end
      case clue.downcase
      when /gz/, /gunzip/
        'gz'
      when /zip/
        'zip'
      when /bz2/, /bunzip2/
        'bz2'
      when /exe/
        'exe'
      end
    end
    
    # The packing type.
    #
    # Default: guessed from URI.
    #
    # Can be specified as: "tar"
    def packing
      clue = if t.options['packing']
        t.options['packing'].to_s
      else
        ::File.extname(uri.path.sub(/\.#{compression}\z/, ''))
      end
      case clue.downcase
      when /tar/
        'tar'
      end
    end
    
    # The glob used to pick a file out of an archive.
    #
    # Example:
    #     RemoteTable.new 'http://www.fueleconomy.gov/FEG/epadata/08data.zip', 'glob' => '/*.csv'
    def glob
      t.options['glob']
    end
    
    # The filename, which can be used to pick a file out of an archive.
    #
    # Example:
    #     RemoteTable.new 'http://www.fueleconomy.gov/FEG/epadata/08data.zip', 'filename' => '2008_FE_guide_ALL_rel_dates_-no sales-for DOE-5-1-08.csv'
    def filename
      t.options['filename']
    end
    
    # Cut columns up to this character
    def cut
      t.options['cut']
    end
    
    # Crop rows after this line
    def crop
      t.options['crop']
    end
    
    # The fixed-width schema, given as an array
    #
    # Example:
    #     RemoteTable.new('http://cloud.github.com/downloads/seamusabshere/remote_table/test2.fixed_width.txt',
    #                      'format' => 'fixed_width',
    #                      'skip' => 1,
    #                      'schema' => [[ 'header4', 10, { :type => :string }  ],
    #                                  [  'spacer',  1 ],
    #                                  [  'header5', 10, { :type => :string } ],
    #                                  [  'spacer',  12 ],
    #                                  [  'header6', 10, { :type => :string } ]])
    def schema
      t.options['schema']
    end
    
    # The name of the fixed-width schema according to Slither
    def schema_name
      t.options['schema_name']
    end
    
    # A proc to call to decide whether to return a row.
    def select
      t.options['select']
    end
    
    # A proc to call to decide whether to return a row.
    def reject
      t.options['reject']
    end
    
    # A hash of options to create a new Errata instance (see the Errata gem at http://github.com/seamusabshere/errata) to be used on every row.
    def errata
      return unless t.options.has_key? 'errata'
      @errata ||= if t.options['errata'].is_a? ::Hash
        ::Errata.new t.options['errata']
      else
        t.options['errata']
      end
    end
    
    # Get the format in the form of RemoteTable::Format::Excel, etc.
    #
    # Note: treats all spreadsheets.google.com URLs as Format::Delimited (i.e., CSV)
    #
    # Default: guessed from file extension (which is usually the same as the URI, but sometimes not if you pick out a specific file from an archive)
    #
    # Can be specified as: "xlsx", "xls", "csv", "ods", "fixed_width", "html"
    def format
      return Format::Delimited if uri.host == 'spreadsheets.google.com'
      clue = if t.options['format']
        t.options['format'].to_s
      else
        ::File.extname t.local_file.path
      end
      case clue.downcase
      when /xlsx/, /excelx/
        Format::Excelx
      when /xls/, /excel/
        Format::Excel
      when /csv/, /tsv/, /delimited/
        Format::Delimited
      when /ods/, /open_?office/
        Format::OpenOffice
      when /fixed_?width/
        Format::FixedWidth
      when /htm/
        Format::HTML
      else
        Format::Delimited
      end
    end
    
    def staging_dir_path #:nodoc:
      return @staging_dir_path if @staging_dir_path.is_a?(::String)
      srand # in case this was forked by resque
      @staging_dir_path = ::File.join ::Dir.tmpdir, 'remote_table_gem', rand.to_s
      ::FileUtils.mkdir_p @staging_dir_path
      @staging_dir_path
    end
  end
end