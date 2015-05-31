require 'readline'

class Wqlang
  def initialize
    @keywords = {
      ',' => :comma,
      ':' => :colon,
      "\r\n" => :line,
      "\n" => :line,
      '==' => :equal,
      '=' => :assign,
      '->' => :arrow,
      '(' => :lpar,
      ')' => :rpar,
      '+' => :add,
      '-' => :sub,
      '*' => :mul,
      '/' => :div,
      '%' => :mod,
      '&&' => :and,
      '||' => :or,
      '>=' => :bigger,
      '>>' => :over,
      '<=' => :smaller,
      '<<' => :under,
      '###' => :comment,
      '#=' => :lncomment,
      'q' => :q,
      'func' => :func,
      'call' => :call,
      'while' => :while,
      'if' => :if,
      'else' => :else,
      'println' => :println,
      'print' => :print,
      'scan' => :scan,
      'quit' => :quit,
      'break' => :break,
    }
    @reserved_words = {
      'true' => true,
      'false' => false,
    }
    @space = {}

    escaped_keys = @keywords.keys.map{|t|Regexp.escape(t)}.join('|')
    @keywords_regexp = /\A\s*?(#{escaped_keys})/
    @str_regexp = /\A\s*('.*?'|".*?")([\s\r\n]*)/

    if ARGV[0]
      # 第一引数のファイルを開き、文字列として@codeに保持。末尾が改行文字でなければならないため、追加する
      begin
        @code = File.read(ARGV[0])
      rescue
        wq_raise(WQRuntimeError, "#{ARGV[0]} may not be a text file", 'FileError')
      end

      @code += "\n"

      # @codeを全て木構造として解釈し、その後実行する
      # tree => [:block, [tree], ...]
      tree = sentences
      # p tree # debug

      eval(tree)
    else
      # 引数なしの場合はシェル対話モードで起動する
      shellmode
    end

  end

  # すべてのコードが木構造になるまで木構造を生成し、それらをtreeに追加する
  # @return tree
  def sentences
    unless stnc = sentence(get_token)
      wq_raise :syntax
    end
    tree = [:block, stnc]
    while stnc = sentence(get_token)
      tree << stnc
    end

    return tree
  end

  # 構文木もしくは1要素を返す
  # tokenがシンボルの場合はそれぞれの処理を行い、文字列の場合はexpressionに渡し、
  # それ以外の場合(数値、構文木)の場合はそのまま返す
  def sentence (token)
    if token.is_a?(Symbol)
      case token
      when :line
        sentence(get_token)
      when :comment
        next until (token = get_token) == :comment
        sentence(get_token)
      when :lncomment
        next until (token = get_token) == :line
        sentence(get_token)
      when :print
        exp = expression(get_token)
        return [:print, exp]
      when :println
        exp = expression(get_token)
        return [:println, exp]
      when :scan
        token = get_token
        if token == :line
          unget_token(token)
          return [:scan, :self]
        else
          return [:scan, token]
        end
      when :if
        cond = condition
        proc = procedure
        if (token = get_token) == :else
          if (token = get_token) == :if
            # if構文木を生成し、else句にネストさせる
            else_proc = sentence(:if)
            return [:if, cond, proc, :else, else_proc]
          else
            wq_raise :syntax unless token == :arrow
            else_proc = procedure
            return [:if, cond, proc, :else, else_proc]
          end
        else
          unget_token(token)
          return [:if, cond, proc]
        end
      when :while
        cond = condition
        proc = procedure
        return [:while, cond, proc]
      when :func
        var = sentence(get_token)
        wq_raise :syntax unless var[0] == :var
        func_name = var[1]
        if (token = get_token) == :colon
          args = argument
          wq_raise :syntax unless get_token == :arrow
        else
          args = []
          wq_raise :syntax unless token == :arrow
        end
        proc = procedure
        return [:func, func_name, args, proc]
      when :call
        var = sentence(get_token)
        wq_raise :syntax unless var[0] == :var
        func_name = var[1]
        if (token = get_token) == :colon
          args = argument
        else
          args = []
          wq_raise :syntax unless token == :line
          unget_token(token)
        end
        return [:call, func_name, args]
      when :quit
        return [:quit]
      when :break
        return [:break]
      else
        return token
      end
    elsif token.is_a?(String)
      expression(token)
    else # Numeric, Array
      return token
    end

  end

  # @return [:proc, [tree], ...]
  # proc is enclosed by :-> and :q
  def procedure
    proc = [:proc]
    until (stnc = sentence(get_token)) == :q
      proc << stnc
    end
    return proc
  end

  # @return [args]
  def argument
    args = []
    token = get_token
    loop do
      args << expression(token)
      token = get_token
      if [:line, :arrow].include?(token)
        unget_token(token)
        break
      end
      wq_raise :syntax unless token == :comma
      token = get_token
    end
    return args
  end

  # @return [:cond, [tree]]
  # cond構文木は解釈した際にtrue/falseを取る
  def condition
    cond = [:cond]
    until (token = get_token) == :arrow
      cond << expression(token)
    end
    return cond
  end

  # 優先度低: [+, -, &&, ||, >>, >=, <<, <=, ==]
  def expression (token = get_token)
    result = term(token)
    token = get_token
    while [:add, :sum, :over, :bigger, :under, :smaller, :and, :or, :equal].include?(token)
      result = [token, result, term]
      token = get_token
    end
    wq_raise :syntax unless [:line, :arrow, :rpar, :colon, :comma].include?(token)
    unget_token(token)
    return sentence(result)
  end

  # 優先度中: [*, /, %]
  def term (token = get_token)
    result = factor(token)
    token = get_token
    while [:mul, :div, :mod].include?(token)
      result = [token, result, factor]
      token = get_token
    end
    unget_token(token)
    return result
  end

  # 優先度高: [(), variable]
  # 数値計算、文字列の解釈、変数の解釈、代入処理
  def factor (token = get_token)
    minusflag = 1
    if token == :sub
      minusflag = -1
      token = get_token
    end

    case token
    when Numeric
      num = token * minusflag
      return num
    when String
      # 内部的に文字列であれば、クォートを除去し文字列として返す
      if token.match(/\A"(.*)"\z/)
        # 特殊文字のエスケープを除去
        str = $1.gsub(/\\n|\\r|\\s|\\t/, "\\n" => "\n", "\\r" => "\r", "\\s" => "\s", "\\t" => "\t")
        return [:str, str]
      elsif token.match(/\A'(.*)'\z/)
        str = $1
        return [:str, str]
      end

      # 内部的な文字列以外で使用禁止の文字が含まれていた場合、シンタックスエラーとする
      wq_raise :syntax unless token =~ /\A\w[\w\-]*\z/

      # tokenが通常の文字列かつ、次のtokenが代入処理であれば処理をし、そうでない場合は予約語と比較し変数呼び出しとする
      var = token
      token = get_token

      if token == :assign
        # 変数代入
        token = get_token
        if [:call, :scan].include?(token)
          val = sentence(token)
        else
          val = expression(token)
        end
        return [:assign, var, val]
      else
        # 変数呼び出し or 引数無し関数呼び出し
        # どちらも:varで木構造を生成し、実行時に判定
        unget_token(token)
        if @reserved_words.has_key?(var)
          return [:reserved, var]
        else
          return [:var, var]
        end
      end
    when :lpar
      # ()に囲われていた場合優先的に再帰して木構造を生成する
      result = expression
      wq_raise :syntax unless get_token == :rpar
      if minusflag == -1
        return [:mul, minusflag, result]
      else
        return result
      end
    end
  end

  def get_token
    case @code
    when @keywords_regexp
      # キーワードに該当
      @code = $'
      return @keywords[$1]
    when @str_regexp
      # シングルクォート、ダブルクォートで囲われた文字列(内部的な文字列)に該当
      @code = $2 + $'
      token = $1
      return token
    when /\A\s*([^\s]*?)([,\(\):\s\n\r])/
      # キーワード、内部文字列以外の部分に該当
      # [],():]は区切りに空白が無い場合も分けて切り出させる
      #   (これらの文字は変数名には使用できない)
      @code = $2 + $'
      token = $1
      case token
      when /\A[\+\-]?\d+\z/
        token = token.to_i
      when /\A[\+\-]?\d+\.\d+\z/
        token = token.to_f
      end
      return token
    else
      # 全コードの解釈完了
      return nil
    end
  end

  # tokenがシンボルの場合はキーワード一覧から文字列に戻し、それ以外は文字列にキャストしてから@codeの前方に戻す
  def unget_token (token)
    if @keywords.has_value?(token)
      return_token = @keywords.invert[token]
    else
      return_token = token.to_s
    end
    @code = return_token + @code
  end


  # 解釈処理は全てbegin-rescueで補足される。ruby由来の演算の例外はここで捉えられ、エラーメッセージとして出力される
  # case文に該当しないものは渡された場合、実行時エラーとするが、構文の誤りである場合もある
  #   (木構造を生成できるが、正しく生成できないコード、例えば許されていないネスト呼び出しであった場合等)
  def eval(ast)
    begin
      #  対象が文字列、数値である場合は、木構造は最後まで解釈されているので、その値を返し終了する
      return ast if ast.is_a? String or ast.is_a? Numeric

      case ast[0]
      when :block
        # [:block, [tree], ...]
        # 最も外の木構造の要素となる木構造を全て解釈し、これの終了は即ちプログラムの実行終了となる
        ast[1..-1].each do |tree|
          eval(tree)
        end
        # p @space # debug
      when :proc
        # [:proc, [tree], ...]
        # proc木の要素となる木構造を全て解釈する
        result = nil
        ast[1..-1].each do |tree|
          result = eval(tree)
          break if result == :break
        end
        return result
      when :print
        # [:print, Literal], [:print, [tree]]
        # 改行なしで文字列を出力
        exp = eval(ast[1])
        print exp
        return exp
      when :println
        # [:println, Literal], [:print, [tree]]
        # 改行ありで文字列を出力
        exp = eval(ast[1])
        puts exp
        return exp
      when :scan
        # [:scan, var], [:scan, :self]
        # 文字列を入力(内部的にも文字列として扱われる)
        print '(stdin)> '
        input = STDIN.gets.chomp
        case input
        when /\A\d+\z/
          val = input.to_i
        when /\A\d+\.\d+\z/
          val = input.to_f
        else
          val = input
        end
        if ast[1] == :self
          # 入力結果を返す
          return val
        else
          # 入力結果を変数に代入する
          var = ast[1]
          @space.store(var, val)
        end
      when :cond
        # [:cond, [tree]]
        # 構文木を解釈し、true/falseを返す
        return !!(eval(ast[1]))
      when :if
        # [:if, cond, proc], [:if, cond, proc, :else, proc]
        cond = eval(ast[1])
        # condはtrue/falseのため、値に応じて実行対象を変更
        # else句に対応するproc木がない場合は実行しない
        result = nil
        if cond
          result = eval(ast[2])
        elsif ast[3] == :else
          result = eval(ast[4])
        end
        return result
      when :while
        # [:while, cond, proc]
        # condがtrueの間のみ実行
        #   (condが変化しないプログラムの場合は当然無限ループとなる)
        # breakの処理を行う為、procとは別に処理を行う
        # eval(ast[2]) while eval(ast[1])
        proc = ast[2]
        catch(:exit) do
          while eval(ast[1])
            proc[1..-1].each do |tree|
              result = eval(tree)
              throw :exit if result == :break
            end
          end
        end
      when :assign
        # [:assign, str, Literal], [:assign, str, [:var, str]]
        # 変数を宣言し、値を名前空間に格納する
        # 木構造の代入要素が変数だった場合、現在の値を取得し代入する(参照にはならない)
        wq_raise :runtime unless ast[1].is_a? String
        var = ast[1]
        val = eval(ast[2])
        @space.store(var, val)
        return val
      when :var
        # [:var, key]
        # 呼び出された変数が通常の変数であれば名前空間より値を取得し返す
        # 呼び出された変数が関数funcobj)であれば、引数無し関数呼び出しのため、callで処理
        key = ast[1]
        wq_raise :runtime unless val = @space[ast[1]]
        if val.is_a?(Array) && val[0] == :funcobj
          args = []
          return eval([:call, key, args])
        else
          return val
        end
      when :func
        # [:func, func_name, [args], [:proc]]
        # 関数を宣言し、funcobjとして名前空間に格納する
        func_name = ast[1]
        args = ast[2]
        proc = ast[3]
        func = [:funcobj, args, proc]
        @space.store(func_name, func)
      when :call
        # [:call, funcname, [args]]
        # 名前空間で参照した対象がfuncobjであるか確認し、異なる場合は実行時エラー
        wq_raise :runtime unless funcobj = @space[ast[1]]
        wq_raise :runtime unless funcobj[0] == :funcobj

        # 関数呼び出し処理内はローカルのスコープとなる
        # 元の名前空間の状態をglobalに退避させ、ローカルスコープから抜けた時に元に戻す
        # 対象の関数と呼び出し時の引数を比較し、ローカルスコープの名前空間に代入
        # 引数の数が違う場合は実行時エラー
        call_args = ast[2]
        func_args = funcobj[1]
        wq_raise :runtime unless call_args.size == func_args.size
        proc = funcobj[2]
        wq_raise :runtime unless proc[0] == :proc
        global = @space.clone
        func_args.each.with_index do |arg, i|
          wq_raise :runtime unless arg[0] == :var
          key = arg[1]
          val = eval(call_args[i])
          @space.store(key, val)
        end

        # 各処理の実行結果をresultに格納。処理終了時のresultを関数の返り値とする
        result = nil
        proc[1..-1].each do |tree|
          result = eval(tree)
        end
        @space = global.clone
        return result
      when :reserved
        # [:reserved, str]
        # 予約語を解釈する
        # 現在はtrue/falseをrubyの内部的なTrueClass/FalseClassへ置換する
        return @reserved_words[ast[1]]
      when :quit
        # 終了する
        exit
      when :break
        # break処理が行われたことをbreakシンボルを渡すことで通知する
        return :break
      when :str
        # 内部的な文字列を解釈する
        return ast[1]

      # 比較、計算処理
      # それぞれの演算結果を返す。演算処理はruby由来となり、許されていない演算の場合は実行時エラーとなる
      when :add
        return eval(ast[1]) + eval(ast[2])
      when :sub
        return eval(ast[1]) - eval(ast[2])
      when :mul
        return eval(ast[1]) * eval(ast[2])
      when :div
        return eval(ast[1]) / eval(ast[2])
      when :mod
        return eval(ast[1]) % eval(ast[2])
      when :and
        return eval(ast[1]) && eval(ast[2])
      when :or
        return eval(ast[1]) || eval(ast[2])
      when :over
        return eval(ast[1]) > eval(ast[2])
      when :bigger
        return eval(ast[1]) >= eval(ast[2])
      when :under
        return eval(ast[1]) < eval(ast[2])
      when :smaller
        return eval(ast[1]) <= eval(ast[2])
      when :equal
        return eval(ast[1]) == eval(ast[2])

      # 未定義の場合に該当するコードは、一見文法に沿っているように見えるが許されてないネスト呼び出し等が該当する
      else
        wq_raise :runtime
      end
    rescue
      # 全ての例外は実行時エラーとして処理される
      wq_raise :runtime
    end
  end

  def wq_raise (error, msg = nil, backtrace = 'UnexpectedError')
    # rubyとしてのエラー処理を隠蔽し、wqlangプログラムのエラーとして出力する
    # グローバル変数$!にエラー内容が記録されているため、eval処理のbegin-rescueで補足されたものについては
    # 演算時のエラーが主であるため、ruby由来のエラーメッセージを出力する
    if ARGV[0] and File.exist?(ARGV[0])
      # 元ソースと@codeを比較し、エラー位置を取得
      source = File.read(ARGV[0])
      unless @code == ''
        source.slice!(@code.chomp)
        error_line = source.count("\n") + 1
        backtrace = "#{ARGV[0]}:#{error_line}"
      else
        backtrace = 'RuntimeError'
      end
    end

    #ErrorMessage => [backtrace]:msg([ErrorType])
    # エラーメッセージ、バックトレースを任意に指定し、raiseから例外を発生させる
    # 発生する例外WQSyntaxErrorクラス、WQRuntimeErrorクラスはStandardErrorクラスを継承
    case error
    when :syntax
      backtrace ||= 'SyntaxError'
      raise WQSyntaxError, $!, backtrace
    when :runtime
      backtrace ||= 'RuntimeError'
      raise WQRuntimeError, $!, backtrace
    else
      raise error, msg, backtrace
    end
  end


  def shellmode
    # shellでの対話型インタプリタ
    # 基本的に一行ずつ解釈、実行されるが、関数宣言等は複数行入力し解釈、実行される
    # @codeの生成がファイル読み取りか入力かの違いのみで、内部の解釈、実行は同様
    # 終了は[quit, .q, :q, :q!]およびCtrl-C
    puts <<-'EOS'
         |¯|      |¯|¯|
       __| |/¯¯¯\ |_|_|
      |__    /¯\ \
       / /  /   | |
      /_/| |    | |
         |_|   /_/
    EOS
    puts 'Welcome to WaQuotes(wakotsu) language!'
    @code = ''
    begin
      loop do
        next if shellscan == nil
        @code += "\n"
        tree = sentences
        # p tree #debug

        eval(tree)
      end
    rescue Interrupt
      # Ctrl-C入力を捕捉し終了メッセージを出力
      puts ''
      puts 'exec Ctrl-C'
      puts 'Bye'
    rescue => e
      puts "RuntimeError: #{e} (WQRuntimeError)"
      retry
    end
  end

  def shellscan
    input = Readline.readline('(wqlang)> ', true)
    case input
    when /\A::debug (.*)\z/
      # デバッグ用コマンド
      cmd = $1
      case cmd
      when 'namespace'
        p @space
      when 'code'
        p @code
      end
      return nil
    when /->\z/
      # proc句の処理に入る
      @code << input + "\n"
      shellproc
    when /\Aquit\z|\A\.q\z|\A:q!?\z/
      puts 'Bye'
      exit
    else
      @code << input + "\n"
    end
    return input + "\n"
  end

  def shellproc
    # proc木の処理に入っているため、入力値がq(proc構造の終了)になるまでループする
    input = shellscan until input =~ /q\n\z/
  end
end

class WQSyntaxError < StandardError
end

class WQRuntimeError < StandardError
end

Wqlang.new