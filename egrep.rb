# egrepを実装

if ARGV[1]
  regexp = /#{ARGV[0]}/
  file_path = ARGV[1]

  file = open(file_path)
  file.each do |line|
    puts line if line =~ regexp
  end
  file.close
end