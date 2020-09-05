//
//  ViewController.swift
//  Stocks
//
//  Created by Polina A. Guseva on 28.08.2020.
//  Copyright © 2020 Polina A. Guseva. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    // UI
    @IBOutlet weak var companyNameLabel: UILabel!
    @IBOutlet weak var companyPickerView: UIPickerView!
    @IBOutlet weak var companySymbolLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var priceChangeLabel: UILabel!
    @IBOutlet weak var companyLogoImageView: UIImageView!
    
    // Private
    // Use https://cloud.iexapis.com/beta/ref-data/symbols?token=TOKEN to view all available symbols.
    // Warning: Over 8800 symbols, so pickerView won't cut it
    private lazy var companies = [String: String]()
    
    private lazy var iexcloud_token = "pk_6f2ec9d0969e45f8a9f2378352b9c919"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        companyPickerView.dataSource = self
        companyPickerView.delegate = self
        
        activityIndicator.hidesWhenStopped = true

        requestSymbols()
    }
    
    // MARK: - Private
    
    private func requestSymbols() {
        activityIndicator.startAnimating()

        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/market/collection/list?collectionName=mostactive&token=\(iexcloud_token)&listLimit=25") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data,
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    error == nil {
                self.parseSymbols(from: data)
            } else {
                DispatchQueue.main.async { [weak self] in
                    let alertController = UIAlertController(title: "Ошибка", message: "Нет доступа к сети.", preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "Выйти", style: .destructive, handler: { (_) in
                        exit(0)
                    }))
                    self?.present(alertController, animated: true, completion: nil)
                }
            }
        }
    
        dataTask.resume()
    }

    private func requestQuoteUpdate() {
        companyLogoImageView.isHidden = true
        activityIndicator.startAnimating()
        companyNameLabel.text = "-"
        companySymbolLabel.text = "-"
        priceLabel.text = "-"
        priceChangeLabel.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        priceChangeLabel.text = "-"

        let selectedRow = companyPickerView.selectedRow(inComponent: 0)
        let selectedSymbol = Array(companies.values)[selectedRow]
        requestQuote(for: selectedSymbol)
        requestLogo(for: selectedSymbol)

        companyLogoImageView.isHidden = false
    }

    private func requestQuote(for symbol: String) {
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/quote?token=\(iexcloud_token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data,
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    error == nil {
                self.parseQuote(from: data)
            } else {
                DispatchQueue.main.async { [weak self] in
                    let alertController = UIAlertController(title: "Ошибка", message: "Проблемы с сетью.", preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                    }))
                    self?.present(alertController, animated: true, completion: nil)
                }
            }
        }
        
        dataTask.resume()
    }
    
    private func requestLogo(for symbol: String) {
        guard let url = URL(string: "https://cloud.iexapis.com/stable/stock/\(symbol)/logo?token=\(iexcloud_token)") else {
            return
        }
        
        let dataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data,
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    error == nil {
                self.retrieveLogo(from:data)
            } else {
                DispatchQueue.main.async { [weak self] in
                    let alertController = UIAlertController(title: "Ошибка", message: "Проблемы с сетью.", preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                    }))
                    self?.present(alertController, animated: true, completion: nil)
                }
            }
        }
        
        dataTask.resume()
    }

    private func parseSymbols(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
    
            guard let json = jsonObject as? [[String: Any]] else {
                DispatchQueue.main.async { [weak self] in
                    let alertController = UIAlertController(title: "Ошибка", message: "Проблемы с сетью.", preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                    }))
                    self?.present(alertController, animated: true, completion: nil)
                }
                return print("Invalid JSON")
            }
            
            for symbolObject in json {
                guard
                    let companyName = symbolObject["companyName"] as? String,
                    let companySymbol = symbolObject["symbol"] as? String else { return print("Invalid JSON") }
                
                companies[companyName] = companySymbol
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.activityIndicator.stopAnimating()
                self?.companyPickerView.reloadAllComponents()
            }
            requestQuoteUpdate()
        } catch {
            DispatchQueue.main.async { [weak self] in
                let alertController = UIAlertController(title: "Ошибка", message: "Проблемы с сетью.", preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                }))
                self?.present(alertController, animated: true, completion: nil)
            }
            print("JSON parsing error: " + error.localizedDescription)
        }
    }

    private func parseQuote(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let companyName = json["companyName"] as? String,
                let companySymbol = json["symbol"] as? String,
                let price = json["latestPrice"] as? Double,
                let priceChange = json["change"] as? Double else { return print("Invalid JSON") }

            DispatchQueue.main.async { [weak self] in
                self?.displayStockInfo(
                    companyName: companyName,
                    companySymbol: companySymbol,
                    price: price,
                    priceChange: priceChange
                )
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                let alertController = UIAlertController(title: "Ошибка", message: "Проблемы с сетью.", preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                }))
                self?.present(alertController, animated: true, completion: nil)
            }
            print("JSON parsing error: " + error.localizedDescription)
        }
    }
    
    private func retrieveLogo(from data: Data) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            guard
                let json = jsonObject as? [String: Any],
                let imgLink = json["url"] as? String else { return print("Invalid JSON") }
            
            guard let imgUrl = URL(string: imgLink) else {
                return
            }
            
            let dataTask = URLSession.shared.dataTask(with: imgUrl) { (data, response, error) in
                if let data = data,
                    (response as? HTTPURLResponse)?.statusCode == 200,
                    error == nil {
                    DispatchQueue.main.async { [weak self] in
                        self?.companyLogoImageView.image = UIImage(data: data)
                    }
                } else {
                    DispatchQueue.main.async { [weak self] in
                        let alertController = UIAlertController(title: "Ошибка", message: "Нет доступа к сети.", preferredStyle: .alert)
                        
                        alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                        }))
                        self?.present(alertController, animated: true, completion: nil)
                    }
                }
            }
            
            dataTask.resume()
        } catch {
            DispatchQueue.main.async { [weak self] in
                let alertController = UIAlertController(title: "Ошибка", message: "Проблемы с сетью.", preferredStyle: .alert)
                
                alertController.addAction(UIAlertAction(title: "Ок", style: .default, handler: { (_) in
                }))
                self?.present(alertController, animated: true, completion: nil)
            }
            print("JSON parsing error: " + error.localizedDescription)
        }
    }

    private func displayStockInfo(companyName: String, companySymbol: String, price: Double, priceChange: Double) {
        activityIndicator.stopAnimating()
        companyNameLabel.text = companyName
        companySymbolLabel.text = companySymbol
        priceLabel.text = "\(price)"
        if priceChange < 0 {
            priceChangeLabel.text = "🔽 \(-priceChange)"
            priceChangeLabel.textColor = #colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1)
        } else if priceChange > 0 {
            priceChangeLabel.text = "🔼 \(priceChange)"
            priceChangeLabel.textColor = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
        } else {
            priceChangeLabel.text = "⏺ \(priceChange)"
            priceChangeLabel.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        }
    }
}

// MARK: - UIPickerViewDataSource

extension ViewController: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return companies.keys.count
    }
}

// MARK: - UIPickerViewDelegate

extension ViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return Array(companies.keys)[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        requestQuoteUpdate()
    }
}
