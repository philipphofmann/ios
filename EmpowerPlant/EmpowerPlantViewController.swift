//
//  EmpowerPlantViewController.swift
//  EmpowerPlant
//
//  Created by William Capozzoli on 3/8/22.
//

import UIKit
import Sentry

class EmpowerPlantViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    let tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    var products = [Product]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Empower Plant"

        self.view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        
        // Dev Note - Comment this out and to see the green background and no data in the rows
        tableView.frame = view.bounds
        
        configureNavigationItems()

        /* TODO
         1 get products from server (so we get http.client span)
         2 check if any products in Core Data -> If Not -> insert the products from response into Core Data
         3 get products from DB (so we get db.query span) and reload the table with this data
         */
        getAllProductsFromServer()
        getAllProductsFromDb()
        
        print("> isEmpty", ShoppingCart.instance.isEmpty)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = products[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = model.title
        return cell
    }
    
    func getAllProductsFromServer() {
        let url = URL(string: "https://application-monitoring-flask-dot-sales-engineering-sf.appspot.com/products-join")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct ProductMap: Decodable {
            // MARK: - Properties
            let id: Int
            let title: String
            let description: String
            let descriptionfull: String
            let img: String
            let imgcropped: String
            let price: Int
            // reviews: [{id: 4, productid: 4, rating: 4, customerid: null, description: null, created: String},...]
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let productsResponse = try? JSONDecoder().decode([ProductMap].self, from: data) {
                    for product in productsResponse {
//                        print(product.title)
                        // Writes to CoreData
                        self.createProduct(productId: String(product.id), title: product.title, productDescription: product.description, productDescriptionFull: product.descriptionfull, img: product.img, imgCropped: product.imgcropped, price: String(product.price))
                    }
                } else {
                    print("Invalid Response")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }

        task.resume()
        
        // Don't Reload Table, because we still have to conver the above JSON objects from the server into Swift objects
//        do {
//            DispatchQueue.main.async {
//                self.tableView.reloadData()
//            }
//        }
//        catch {
//            //error
//        }
    }
    
    func getAllProductsFromDb() {
        do {
            self.products = try context.fetch(Product.fetchRequest())
            
            // TEMPORARY - this is for testing purposes only
//            for product in self.products {
//                deleteProduct(product: product)
//            }
            
//            for product in self.products {
//                print(product.productId, product.title, product.productDescriptionFull)
//            }
            refreshTable()
//            DispatchQueue.main.async {
//                self.tableView.reloadData()
//            }
        }
        catch {
            // error
        }
    }
    
    //func createProduct(id: Int, title: String, description: String, descriptionfull: String, img: String, imgcropped: String, price: price) {
    func createProduct(productId: String, title: String, productDescription: String, productDescriptionFull: String, img: String, imgCropped: String, price: String) {
        let newProduct = Product(context: context)
        
        newProduct.productId = productId // 'id' was a reserved word in swift
        newProduct.title = title
        newProduct.productDescription = productDescription // 'description' was a reserved word in swift
        newProduct.productDescriptionFull = productDescriptionFull
        newProduct.img = img
        newProduct.imgCropped = imgCropped
        newProduct.price = price
        
//        let id: Int
//        let title: String
//        let description: String
//        let descriptionfull: String
//        let img: String
//        let imgcropped: String
//        let price: Int
        do {
            try context.save()
            getAllProductsFromDb()
        }
        catch {
            // error
        }
    }

    func deleteProduct(product: Product) {
        context.delete(product)
        do {
            try context.save()
        }
        catch {
            
        }
    }

    func updateProduct(product: Product, newTitle:  String) {
        product.title = newTitle
        do {
            try context.save()
        }
        catch {
            
        }
    }
    
    private func configureNavigationItems() {
        
        // TODO - put goToCart back eventually for the below #selector
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cart",
            style: .plain,
            target: self,
            action: #selector(addToDb)
        )
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "List App",
            style: .plain,
            target: self,
            action: #selector(goToListApp)
        )
    }
    
    @objc
    func addToDb() {
        let alert = UIAlertController(title: "New Product",
                                      message: "Enter new product title",
                                      preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        
        // WORKS
        alert.addAction(UIAlertAction(title:"Submit", style: .cancel, handler: { [weak self] _ in
            guard let field = alert.textFields?.first, let text = field.text, !text.isEmpty else {
                return
            }
            self?.createProduct(productId: "123", title: text, productDescription: "product.description", productDescriptionFull: "product.description.full", img:"img", imgCropped:"img.cropped", price:"1")
        }))
        
        self.present(alert, animated: true, completion: nil)
        
        // ALSO WORKED
//        alert.addTextField()
//        let submitButton = UIAlertAction(title:"Add", style: .default) { (action) in
//            print("here")
//            let textfield = alert.textFields![0]
//        }
//        alert.addAction(submitButton)
//        self.present(alert, animated: true, completion: nil)
    }
    
    @objc
    func goToCart() {
        self.performSegue(withIdentifier: "goToCart", sender: self)
    }
    
    @objc
    func goToListApp() {
        self.performSegue(withIdentifier: "goToListApp", sender: self)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @objc
    func refreshTable() {
//        print("> refresh table") // why is this executing so much
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}
