require "set"

# Trifecta / 3連単の買い目をここに書く。
#
# 形式：
#   1着-2着-3着
#
# 例：
#   3-10-12
#
# これは、
#   1着: 3
#   2着: 10
#   3着: 12
# を意味する。
#
# Trifecta / 3連単では順序が重要なので、
# 3-10-12 と 12-10-3 は別の買い目として扱う。
BET_TEXT = <<~TEXT
3-10-12
3-10-18
3-12-16
3-12-18
3-16-18
8-10-12
8-10-18
8-12-16
8-12-18
8-16-18
10-12-13
10-12-16
10-12-18
10-13-18
10-16-18
12-13-16
12-13-18
12-16-18
13-16-18
TEXT

# ------------------------------------------------------------
# 買い目を読み込む
#
# Trifecta / 3連単では順序が重要なので、ソートしない。
#
# 例：
#   3-10-12 は [3, 10, 12]
#   12-10-3 は [12, 10, 3]
#
# として、別々の買い目として扱う。
# ------------------------------------------------------------
def parse_bets(text)
  bets = Set.new

  text.each_line do |line|
    line = line.strip
    next if line.empty?

    nums = line.split("-").map(&:to_i)

    raise "3頭ではありません: #{line}" unless nums.length == 3
    raise "同じ馬番が重複しています: #{line}" unless nums.uniq.length == 3

    bets.add(nums)
  end

  bets
end

# ------------------------------------------------------------
# bit mask を馬番リストに変換する
#
# mask の各 bit が「その馬を列に入れるかどうか」を表す。
# これにより、馬番集合のすべての部分集合を
# 1着列・2着列・3着列の候補として列挙できる。
# ------------------------------------------------------------
def bits_to_list(mask, horses)
  horses.each_with_index
        .select { |_, i| (mask & (1 << i)) != 0 }
        .map(&:first)
end

# ------------------------------------------------------------
# 3つの列から Trifecta / 3連単の買い目を生成する
#
# 1着候補・2着候補・3着候補から1頭ずつ選び、
# 順序つきの3頭の組を作る。
#
# 同じ馬を2回以上選ぶことはできないので、重複馬番は除外する。
#
# Trifecta / 3連単は順序を保持するため、ソートしない。
# ------------------------------------------------------------
def generated_triples(first_col, second_col, third_col)
  result = Set.new

  first_col.product(second_col, third_col) do |a, b, c|
    next unless [a, b, c].uniq.length == 3
    result.add([a, b, c])
  end

  result
end

# ------------------------------------------------------------
# 買い目集合と完全一致する Trifecta / 3連単フォーメーションを探す
#
# アルゴリズム：
#
# 1. 元の買い目に登場する馬番をすべて集める。
# 2. その馬番集合の空でない部分集合をすべて作る。
# 3. それぞれを1着列・2着列・3着列の候補として試す。
# 4. 各フォーメーションから生成される Trifecta / 3連単の集合を作る。
# 5. 元の買い目集合と完全一致するものだけを解として採用する。
# 6. 合計マーク数が少ない順に並べる。
#
# Trio / 三連複と違い、Trifecta / 3連単では列順そのものに意味がある。
# そのため、列順を省略せず、すべての順序つき列候補を探索する。
# ------------------------------------------------------------
def find_formations(target, top_k: 20)
  horses = target.to_a.flatten.uniq.sort
  n = horses.length
  masks = (1...(1 << n)).to_a
  solutions = []

  masks.each do |m1|
    masks.each do |m2|
      masks.each do |m3|
        first_col = bits_to_list(m1, horses)
        second_col = bits_to_list(m2, horses)
        third_col = bits_to_list(m3, horses)

        made = generated_triples(first_col, second_col, third_col)

        solutions << [first_col, second_col, third_col] if made == target
      end
    end
  end

  solutions.sort_by do |cols|
    [
      cols.map(&:length).sum,
      cols.map(&:length).max,
      cols.map(&:length),
      cols
    ]
  end.first(top_k)
end

def format_formation(cols)
  labels = ["1着", "2着", "3着"]

  cols.each_with_index.map do |col, i|
    "#{labels[i]}: #{col.join(",")}"
  end.join(" / ")
end

target = parse_bets(BET_TEXT)
solutions = find_formations(target)

puts "元の買い目数: #{target.length}点"
puts

if solutions.empty?
  puts "完全一致する Trifecta / 3連単フォーメーションは見つかりませんでした。"
  puts
  puts "この場合、以下の可能性があります。"
  puts "- 買い目がフォーメーションではなく個別指定である"
  puts "- 入力の一部が抜けている"
  puts "- 入力に余分な買い目が入っている"
else
  solutions.each_with_index do |cols, i|
    generated = generated_triples(*cols)
    marks = cols.map(&:length).sum

    puts "[#{i + 1}] #{format_formation(cols)}"
    puts "    マーク数: #{marks}"
    puts "    生成点数: #{generated.length}点"
    puts
  end
end
