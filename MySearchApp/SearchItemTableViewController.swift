

import UIKit
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


//商品リスト画面
class SearchItemTableViewController: UITableViewController, UISearchBarDelegate {

    //商品情報を格納する配列
    var itemDataArray = [ItemData]()
    
    //商品画像のキャッシュを管理するクラス
    var imageCache = NSCache<AnyObject, AnyObject>()
    
    //APIを利用するためのアプリケーションID
    let appid: String = "dj0zaiZpPTJBRThHaDNoWk1wZCZzPWNvbnN1bWVyc2VjcmV0Jng9Zjg-"
    
    //APIのURL
    let entryUrl: String = "https://shopping.yahooapis.jp/ShoppingWebService/V1/json/itemSearch"
    
    //数字を金額の形式に整形するためのフォーマッター
    let priceFormat = NumberFormatter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //価格のフォーマット設定
        priceFormat.numberStyle = .currency
        priceFormat.currencyCode = "JPY"
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - search bar delegate
    //キーボードのsearchボタンがタップされた時に呼び出される
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        //商品検索を行なう
        let inputText = searchBar.text
        //入力文字数が0文字以上かどうかチェックする
        if (inputText?.lengthOfBytes(using: String.Encoding.utf8)) > 0 {
            //保持している商品を一旦削除
            itemDataArray.removeAll()
            
            //パラメータを指定する
            let parameter = ["appid":appid, "query":inputText]
            
            //パラメータをエンコードしたURLを作成する
            let requestUrl = createRequestUrl(parameter as! [String : String])
            
            //APIをリクエストする
            request(requestUrl)
        }
        //キーボードを閉じる
        searchBar.resignFirstResponder()
    }
    
    //URL作成処理
    func createRequestUrl(_ parameter :[String:String]) -> String {
        var parameterString = ""
        for key in parameter.keys {
            if let value = parameter[key] {
                //既にパラメータが設定されていた場合
                if parameterString.lengthOfBytes(
                    using: String.Encoding.utf8) > 0 {
                    parameterString += "&"
                }
                
                //値をエンコードする
                if let escapedValue =
                    value.addingPercentEncoding(
                        withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                    parameterString += "\(key)=\(escapedValue)"
                }
            }
        }
        let requestUrl = entryUrl + "?" + parameterString
        return requestUrl
    }
    
    //リクエストを行なう
    func request(_ requestUrl: String) {
        //商品検索APIをコールして商品検索を行なう
        let session = URLSession.shared

        if let url = URL(string: requestUrl){
            let request = URLRequest(url: url)
            
            let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
                //エラーチェック
                if error != nil {
                    //エラー表示
                    let alert = UIAlertController(title: "エラー",
                        message: (error! as NSError).description,
                        preferredStyle: UIAlertControllerStyle.alert)
                    //UIに関する処理はメインスレッド上で行なう
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.present(alert, animated: true, completion: nil)
                    })
                    return
                }
                
                //Jsonで返却されたデータをパースして格納する
                if let data = data {
                    let jsonData = try! JSONSerialization.jsonObject(
                    with: data, options: .allowFragments) as? [String:Any]
                    //データのパース処理
                    if let resultSet = jsonData?["ResultSet"] as? [String: Any] {
                        self.parseData(resultSet as [String : AnyObject])
                    }
                    
                    //テーブルの描画処理を実施
                    DispatchQueue.main.async{ [weak self] in
                        self?.tableView.reloadData()
                    }
                }
            })
                task.resume()
        }
    }
    
    //検索結果をパースして商品リストを作成する
    func parseData(_ resultSet: [String:AnyObject]) {
        if let firstObject = resultSet["0"] as? [String:AnyObject] {
            if let results = firstObject["Result"] as? [String:AnyObject] {
                for key in results.keys.sorted() {
                    
                    //Requestのキーは無視する
                    if key == "Request" {
                        continue
                    }
                    
                    //商品アイテム取得処理
                    if let result = results[key] as? [String:AnyObject] {
                        //商品データ格納オブジェクト作成
                        let itemData = ItemData()
                        
                        //画像を格納
                        if let itemImageDic = result["Image"] as? [String:AnyObject] {
                            let itemImageUrl = itemImageDic["Medium"] as? String
                            itemData.itemImageUrl = itemImageUrl
                        }
                        
                        //商品タイトルを格納
                        let itemTitle = result["Name"] as? String //商品名
                        itemData.itemTitle = itemTitle
                        
                        //商品価格を格納
                        if let itemPriceDic = result["Price"] as? [String:AnyObject] {
                            let itemPrice = itemPriceDic["_value"] as? String
                            itemData.itemPrice = itemPrice
                        }
                        
                        //商品のURLを格納
                        let itemUrl = result["Url"] as? String
                        itemData.itemUrl = itemUrl
                        
                        //商品リストに追加
                        self.itemDataArray.append(itemData)
                    }
                }
            }
        }
    }

    // MARK: - Table view data source
    //テーブルセルの取得処理
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "itemCell", for: indexPath) as! ItemTableViewCell
        let itemData = itemDataArray[indexPath.row]
        //商品タイトル設定処理
        cell.itemTitleLabel.text = itemData.itemTitle
        //商品価格設定処理（日本通貨の形式で設定する）
        let number = NSNumber(value: Int(itemData.itemPrice!)! as Int)
        cell.itemPriceLabel.text = priceFormat.string(from: number)
        //商品のURL設定
        cell.itemUrl = itemData.itemUrl
        //画像の設定処理
        //既にセルに判定されている画像と同じかどうかチェックする
        //画像がまだ設定されていない場合に処理を行なう
        if let itemImageUrl = itemData.itemImageUrl {
            //キャッシュの画像を取り出す
            if let cacheImage = imageCache.object(forKey: itemImageUrl as AnyObject) as? UIImage {
                //キャッシュの画像を設定
                cell.itemImageView.image = cacheImage
            } else {
                //画像のダウンロード処理
                let session = URLSession.shared
                if let url = URL(string: itemImageUrl){
                    let request = URLRequest(url: url)
                    let task = session.dataTask(
                        with: request, completionHandler: {
                            (data:Data?, response:URLResponse?, error:Error?) -> Void in
                        if let data = data {
                            if let image = UIImage(data: data) {
                                //ダウンロードした画像をキャッシュに登録しておく
                                self.imageCache.setObject(image, forKey: itemImageUrl as AnyObject)
                                //画像はメインスレッド上で設定する
                                DispatchQueue.main.async(execute: { () -> Void in
                                    cell.itemImageView.image = image
                                })
                            }
                        }
                    })
                    //画像の読み込み処理開始
                    task.resume()
                }
            }
        }
        return cell
    }
    
    //セクションの数取得処理
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    //アイテムの数取得処理
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemDataArray.count
    }
    

    
    //商品をタップして次の画面に遷移する前の処理
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let cell = sender as? ItemTableViewCell {
            if let webViewController = segue.destination as? WebViewController {
                //商品ページのURLを設定する
                webViewController.itemUrl = cell.itemUrl
            }
        }
    }
}
