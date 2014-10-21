# wc.rb

# # # # #
# wc_init関数でコマンドライン引数、オプションの処理をし、wc_exec関数で実際の処理を行い出力する
# ファイルがディレクトリである場合やオプションが正しくない場合、ファイルが存在しない場合はwcコマンドと同様のエラーを出力する
# 無効な文字コードが含まれる場合はUTF-16を経由しUTF-8の?に置換するが、単語数/文字数が合致しない場合がみられた
#
# *** Lv.1 ***
# 単語数は"#{(空白|改行)以外}#{空白|改行|末尾}"の組み合わせで1単語と判断
### 明示的にするべきかと考えたが、アルファベット以外への対応を考えこの表現とした
# String.sgub関数で便宜上1単語をwに置換し、その後文字数を取得
# wcコマンドと同様全角スペースは単語区切りに含めていない
#
# *** Lv.2 ***
# バイト数、文字数はそれぞれbytesize関数、size関数を用いることで、アルファベット以外にも対応
# 行数は改行文字\nの個数をカウント
### wcコマンドでは最後の行はカウントされていないようなので末尾判定は無視
# 出力形式はwcコマンド同様8文字右詰めとした
#
# *** Lv.3 ***
# 第一引数がオプションであるか正規表現で判定し、マッチした場合はwc_exec関数に渡しcase文で処理
# 不要な計算を避けるため各出力ごとに出力のために同じ処理を書いている
#
# *** Lv.4 ***
# 単一ファイル指定からワイルドカードによるディレクトリ指定、複数ファイル/ディレクトリの連記に対応
# コマンドライン引数にワイルドカードを与えると配列としてARGVに格納されるため、それらをすべてpathsとして扱う
### そのため、pathsの要素は全てワイルドカード無しのファイルのパスとなる
# file_pathsの要素数から複数ファイルであと判定された場合、
# multifiles変数をtrueで宣言することで複数処理であるとし、合計結果用の変数を宣言する
# # # # #

def wc_init
  opt_regexp = /\-(.*)/
  # 第一引数について判定
  if ARGV[0] =~ opt_regexp
    # 第一引数がオプション形式の場合、clmwであるかを判定し、該当すれば第二引数以降をpathsとする
    file_paths = ARGV[1..-1]
    command = $1
    unless command =~ /^[clmw]$/
      STDERR.puts "wc.rb: illegal option -- #{command}\nusage: ruby wc.rb [-clmw] [file ...]"
      exit
    end
  else
    # 第一引数がオプション形式でない場合、第一引数以降をpathsとする
    file_paths = ARGV[0..-1]
    command = nil
  end

  # 該当ファイルが複数ある場合のみ、multifilesであるとし、合計結果用の変数を宣言する
  unless file_paths.size == 1
    $multifiles = true

    $total_bytes = 0
    $total_lines = 0
    $total_chars = 0
    $total_words = 0
  end

  file_paths.each do |file_path|
    unless File.exist?(file_path)
      STDERR.puts "wc.rb: #{file_path}: open: No such file or directory"
      next
    end
    if File::ftype(file_path) == "directory"
      STDERR.puts "wc.rb: #{file_path}: read: Is a directory"
      next
    end
    wc_exec(file_path, command)
  end

  printf "%8d%8d%8d %s\n", $total_lines, $total_words, $total_bytes, 'total' if $multifiles == true
end

def wc_exec (file_path, command = nil)
  regexp = /[^\s\n]+([\s\n]+|$)/ # アルファベット以外にも対応
  file = File.read(file_path)

  begin
    case command
    when 'c'  # バイト数
      bytes = file.bytesize
      $total_bytes += bytes if $multifiles
      printf "%8d %s\n", bytes, file_path
    when 'l'  # 行数
      lines = file.count("\n")
      $total_lines += lines if $multifiles
      printf "%8d %s\n", lines, file_path
    when 'm'  # 文字数
      chars = file.size
      $total_chars += chars if $multifiles
      printf "%8d %s\n", chars, file_path
    when 'w'  #単語数
      words = file.gsub(regexp, 'w').size
      $total_words += words if $multifiles
      printf "%8d %s\n", words, file_path
    else
      lines = file.count("\n")
      words = file.gsub(regexp, 'w').size
      bytes = file.bytesize
      if $multifiles == true
        $total_lines += lines
        $total_words += words
        $total_bytes += bytes
      end
      printf "%8d%8d%8d %s\n", lines, words, bytes, file_path
    end
  rescue => e
    # STDERR.puts e
    # 直接の置換でうまくいかなかったため、UTF-16を経由
    file.encode!('UTF-16', 'UTF-8', invalid: :replace, replace: '?').encode!('UTF-8')
    retry
  end
end

wc_init