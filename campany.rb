require 'open-uri'
require 'nokogiri'
require 'pp'

# TODO: htmlの作成部分が汎用性ない
# TODO: 採用情報無い時, topのurlを返す
# TODO: 更新したときだけ通知とか

# spiderモジュール
class Recnavi 
  def initialize(id)
    @id = id
    @domain = "https://job.rikunabi.com"
    @top_url = "https://job.rikunabi.com/2016/company/top/#{@id}/"
    @top_doc = nil
    @seminar_doc = nil
  end

  def top_doc
    return @top_doc if @top_doc
    @top_doc = doc(@top_url)
  end

  def seminar_doc
    return @seminar_doc if @seminar_doc
    @seminar_doc = doc(event_link)
  end

  # セミナー予約ページ内に日程が複数存在したときにurlを取得
  # urlにドメインを付加した絶対パスを返す
  def seminar_nest_urls
    links = links_to_follow(seminar_doc, /\/2016\/company\/preseminar\/#{@id}\/V\d+\//)
    # 絶対パスにする
    links = links.map { |link| @domain + link }
    links.sort! if !links.empty?
    links
  end

  def schedule_htmls
    schedules = []
    if seminar_nest_urls.empty?
      # 日程がネストされてない場合
      html = schedule_html(seminar_doc)
      schedules << html if html != ""
    else
      # 日程がネストされている場合
      seminar_nest_urls.each do |url|
        html = schedule_html(doc(url))
        schedules << html if html != ""
      end
    end
    schedules
  end

  # 日程部分のHTML
  # TODO: 日程のネストも考慮すべき
  def schedule_html(target_doc)
    html = target_doc.css('table[width="710"][border="0"][cellpadding="0"][cellspacing="0"].g_ml20.g_mb10').to_html rescue ""
    html = clean_html(html)
    html
  end
  
  # 企業名
  def name
    name = ""
    name = top_doc.css(".rnhn_h2.gh_large.g_mb10.g_mt0").text if top_doc
    name
  end

  # eventのリンクを返す
  # 存在しない時 nilを返す
  def event_link
    return nil if !top_doc
    event_nodes = top_doc.css("#lnk_koshatubu_setevent_pre") # ここのdom変わりそう
    link = nil
    link = @domain + event_nodes[0][:href] if !event_nodes.empty?
    link
  end
  
  private 
  
  # htmlを取得し,Nokogiriのフォーマットに整形
  # htmlが無い場合はnilを返却
  def doc(url)
    html = open(url) rescue nil
    Nokogiri::HTML(html) if !html.nil? rescue nil
  end

  # anemoneから流用
  # 正規表現で一部のリンクを取得
  def links_to_follow(doc, regex)
    links = links(doc)
    part_links = []
    links.each do |link|
      if link.to_s =~ regex
        part_links << link
      end
    end
    part_links
  end

  #
  # Array of distinct A tag HREFs from the page
  #
  def links(doc)
    links = []
    doc.search("//a[@href]").each do |a|
      u = a['href']
      next if u.nil? or u.empty?
      links << u
    end
    links.uniq!
    links
  end

  # htmlにタブ, 改行コードなどを除いて整形処理を行う
  def clean_html(html)
    h = html.delete("\t\n\r")
    h
  end
end

if __FILE__ == $0
  require 'minitest/autorun'

  MiniTest.autorun
  class MyTest < MiniTest::Test
    def setup
      # タマノイ酢株式会社
      id = "r395400074"
      @recnavi = Recnavi.new(id)

      id = "r282300039"
      @recnavi_not_event = Recnavi.new(id)
      
      # テレコムサービス株式会社
      # 説明会ページに説明会が複数存在するサイト
      # http://job.rikunabi.com/2016/company/preseminars/r394130001/
      id = "r394130001"
      @recnavi_nest = Recnavi.new(id)
      
      # "r395400074", # タマノイ酢株式会社
      # "r282300039", # カンロ株式会社
      # "r659010039", # 日本ハムグループ
      # "r727640069", # 株式会社サンヨーフーズ
      # # 井村屋
      # "r309300012", # 敷島製パン株式会社(pasco)
      # "r717500005", # 日本製粉株式会社
      # ###
      # "r309200086", # 大石産業株式会社
      # "r208310069", # アンダーツリー株式会社
      # "r394130001", # テレコムサービス株式会社
      # "r494361000"  # 株式会社glob
    end

    def teardown
    end

    def test_イベントあるときリンクはある
      assert !@recnavi.event_link.nil?
    end
    
    def test_イベントないときリンクはない
      assert_equal @recnavi_not_event.event_link, nil
    end
    
    def test_イベントあるとき情報がある
      assert !!@recnavi.seminar_doc
    end

    def test_イベントないとき情報取得できない
      assert_equal @recnavi_not_event.seminar_doc, nil
    end

    def test_recnavi_topから企業ネームを取得
      assert @recnavi.name != ""
    end
    
    def test_日程のHTMLを取得
      assert @recnavi.schedule_htmls != [], "説明会情報がネストしてない場合上手く行かない"
      # 説明会ページ > 説明会情報があるときに上手く動作する
      assert @recnavi_nest.schedule_htmls != [], "説明会情報がネストしている場合上手く行かない"
    end
  end
end

