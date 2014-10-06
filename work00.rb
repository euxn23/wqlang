# coding: utf-8

# char型の配列として扱う
# 引数が2つ存在する場合、第1引数を対象文字列、第2引数をパターン文字列とする
if ARGV.size == 2
  text = ARGV[0].split('')
  patt = ARGV[1].split('')
else
  print 'text: '
  text = STDIN.gets.chomp.to_s
  print 'pattert: '
  patt = STDIN.gets.chomp.to_s
end


m = text.size
n = patt.size
results = Array.new

m.times do |i|
  results << {index: i+1} if text[i..(i+n-1)] == patt
end

puts "マッチ件数: #{results.size}件"
results.each do |result|
  puts "  #{result[:index]}〜#{result[:index]+n-1}文字目"
end
