//
//  EmpowerPlantViewController.swift
//  EmpowerPlant
//
//  Created by William Capozzoli on 3/8/22.
//

import UIKit
import Sentry

class EmpowerPlantViewController: UIViewController {
    
    // CoreData database
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    // Product Entity, gets written to CoreData
    var products = [Product]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Empower Plants"
        
        self.view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        // Configures the nav bar buttons
        configureNavigationItems()
        
        // ???: looks like this was already done?
        /* TODO: implement:
         1 get products from server (so we get http.client span)
         2 check if any products in Core Data -> If Not -> insert the products from response into Core Data
         3 get products from DB (so we get db.query span) and reload the table with this data
         */
        
        getAllProductsFromServer()
        getAllProductsFromDb()
        readCurrentDirectory()
        performLongFileOperation()
        processProducts()
        checkRelease()
        
        
        NotificationCenter.default.addObserver(forName: modifiedDBNotificationName, object: nil, queue: nil) { _ in
            self.getAllProductsFromDb()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }
    
    func performLongFileOperation() {
        let longString = String(repeating: UUID().uuidString, count: 5_000_000)
        let data = longString.data(using: .utf8)!
        let filePath = FileManager.default.temporaryDirectory.appendingPathComponent("tmp" + UUID().uuidString)
        try! data.write(to: filePath)
        try! FileManager.default.removeItem(at: filePath)
    }

    func processProducts() {
        let span = SentrySDK.span?.startChild(operation: "product_processing")
        _ = getIterator(42);
        sleep(50 / 1000)
        span?.finish()
    }

    func getIterator(_ n: Int) -> Int {
       if (n <= 0) {
           return 0;
       }
       if (n == 1 || n == 2) {
           return 1;
       }
       return getIterator(n - 1) + getIterator(n - 2);
   }

    
    
    func readCurrentDirectory() {
        let path = FileManager.default.currentDirectoryPath
        let maxDepth = 5 // Prevent too deep recursion
        
        do {
            // Single pass through directory structure
            try readDirectory(path: path, currentDepth: 0, maxDepth: maxDepth)
        } catch {
            SentrySDK.capture(error: error)
        }
    }
    
    func readDirectory(path: String, currentDepth: Int, maxDepth: Int) throws {
        // Guard against excessive recursion
        guard currentDepth < maxDepth else {
            return
        }
        
        let fm = FileManager.default
        let span = SentrySDK.span?.startChild(operation: "file.read_directory")
        span?.setData(value: path, key: "path")
        defer { span?.finish() }
        
        let items = try fm.contentsOfDirectory(atPath: path)
        
        for item in items {
            let fullPath = (path as NSString).appendingPathComponent(item)
            var isDirectory: ObjCBool = false
            
            if fm.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // Only recurse into directories
                    try readDirectory(
                        path: fullPath,
                        currentDepth: currentDepth + 1,
                        maxDepth: maxDepth
                    )
                }
            }
        }
    }
        }
        return n1
    }
    
    @objc
    func addToDb() {
        let alert = UIAlertController(title: "New Product",
                                      message: "Enter new product title",
                                      preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        
        alert.addAction(UIAlertAction(title:"Submit", style: .cancel, handler: { [weak self] _ in
            guard let field = alert.textFields?.first, let text = field.text, !text.isEmpty else {
                return
            }
            self?.createProduct(productId: "123", title: text, productDescription: "product.description", productDescriptionFull: "product.description.full", img:"img", imgCropped:"img.cropped", price:"1")
        }))
        
        self.present(alert, animated: true, completion: nil)
        
        // ALSO WORKED
        // alert.addTextField()
        // let submitButton = UIAlertAction(title:"Add", style: .default) { (action) in
        //     print("here")
        //     let textfield = alert.textFields![0]
        // }
        // alert.addAction(submitButton)
        // self.present(alert, animated: true, completion: nil)
    }
    
    // Don't deprecate, this function is useful for development and testing
    @objc
    func clearDb() {
        print("> clearDb")
        // self.products was already set by viewDidLoad()
        // self.products = try context.fetch(Product.fetchRequest())
        for product in self.products {
            deleteProduct(product: product)
        }
        refreshTable()
    }
    
    private func configureNavigationItems() {
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "cart"),
            style: .plain,
            target: self,
            action: #selector(goToCart) // addToDb
        )
        self.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "Cart"
        //self.navigationItem.rightBarButtonItem?.badgeValue = "\(1)"
        
        self.navigationItem.leftBarButtonItems = [UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: self,
            action: #selector(goToListApp)
        ), UIBarButtonItem(title: "DB", style: .plain, target: self, action: #selector(dbActions))]
    }
    
    @objc func dbActions() {
        let actionSheet = UIAlertController(title: "Database actions", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Generate items", style: .default, handler: { _ in
            self.generateDBItems()
        }))
        actionSheet.addAction(UIAlertAction(title: "Clear DB", style: .default, handler: { _ in
            wipeDB()
            NotificationCenter.default.post(name: modifiedDBNotificationName, object: nil)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .destructive))
        present(actionSheet, animated: true)
    }
    
    func generateDBItems() {
        let defaultTotalItems = 100_000
        let alert = UIAlertController(title: "Add items", message: nil, preferredStyle: .alert)

        var numberOfItemsTextField: UITextField?
        alert.addTextField { textfield in
            textfield.placeholder = "Number of items (default: \(defaultTotalItems))"
            textfield.keyboardType = .numberPad
            numberOfItemsTextField = textfield
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            var totalItems = (numberOfItemsTextField?.text as? NSString)?.integerValue ?? defaultTotalItems
            if totalItems == 0 {
                totalItems = defaultTotalItems
            }
            var itemsPerBatch = 1_000
            let batches = totalItems / itemsPerBatch
            
            let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
            DispatchQueue.global(qos: .utility).async {
                for i in 0..<batches {
                    DispatchQueue.main.async {
                        for j in 0..<itemsPerBatch {
                            let newProduct = Product(context: context)
                            let productNum = i * itemsPerBatch + j
                            
                            newProduct.productId = "Product \(productNum)" // 'id' was a reserved word in swift
                            newProduct.title = "Product \(productNum)"
                            newProduct.productDescription = "Description for product \(i)" // 'description' was a reserved word in swift
                            newProduct.productDescriptionFull = "Full description for product \(productNum)"
                            newProduct.img = "img"
                            newProduct.imgCropped = "img.cropped"
                            newProduct.price = "\(productNum)"
                        }
                        
                        do {
                            try context.save()
                            NotificationCenter.default.post(name: modifiedDBNotificationName, object: nil)
                        } catch {
                            // TODO: error
                        }
                    }
                    // add a small delay so it doesn't lock up the UI
                    usleep(100_000) // 100 milliseconds
                }
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive))
        present(alert, animated: true)
    }
    
    // Writes to CoreData database
    func createProduct(productId: String, title: String, productDescription: String, productDescriptionFull: String, img: String, imgCropped: String, price: String) {
        let newProduct = Product(context: context)
        
        newProduct.productId = productId // 'id' was a reserved word in swift
        newProduct.title = title
        newProduct.productDescription = productDescription // 'description' was a reserved word in swift
        newProduct.productDescriptionFull = productDescriptionFull
        newProduct.img = img
        newProduct.imgCropped = imgCropped
        newProduct.price = price
    }
    
    // Don't deprecate this until major release of this demo
    func deleteProduct(product: Product) {
        context.delete(product)
        do {
            try context.save()
        }
        catch {
            // TODO: error
        }
    }
    
    func getAllProductsFromDb() {
        do {
            self.products = try context.fetch(Product.fetchRequest())
            // for product in self.products {
            //     print(product.productId, product.title, product.productDescriptionFull)
            // }
            refreshTable()
        }
        catch {
            // TODO: error
        }
    }
    
    // Also writes them into database if database is empty
    func getAllProductsFromServer() {
        let startTime = Date()
        let urlStr = "https://application-monitoring-flask-dot-sales-engineering-sf.appspot.com/products-join"
        let url = URL(string: urlStr)!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct ProductMap: Decodable {
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
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            /*SentrySDK.metrics.distribution(
                key: "products_request.duration",
                value: duration,
                unit: MeasurementUnitDuration.millisecond,
                tags: ["endpoint": urlStr]
            )*/
            
            if let data = data {
                if let productsResponse = try? JSONDecoder().decode([ProductMap].self, from: data) {
                    if (self.products.count == 0) {
                        var operations = [BlockOperation]()
                        let saveOp = BlockOperation() {
                            do {
                                try self.context.save()
                                self.getAllProductsFromDb()
                            } catch {
                                // TODO: error
                            }
                        }
                        for product in productsResponse {
                            // Writes to CoreData database
                            let addOp = BlockOperation() {
                                self.createProduct(productId: String(product.id), title: product.title, productDescription: product.description, productDescriptionFull: product.descriptionfull, img: product.img, imgCropped: product.imgcropped, price: String(product.price))
                            }
                            operations.append(addOp)
                            saveOp.addDependency(addOp)
                        }
                        if operations.count > 0 {
                            operations.append(saveOp)
                            OperationQueue.main.addOperations(operations, waitUntilFinished: false)
                        }
                    }
                } else {
                    print("Invalid Response")
                    // TODO: error
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
                // TODO: error
            }
        }
        
        task.resume()
    }
    
    @objc
    func goToCart() {
        //SentrySDK.metrics.increment(key: "checkout.click")
        self.performSegue(withIdentifier: "goToCart", sender: self)
    }
    
    @objc
    func goToListApp() {
        self.performSegue(withIdentifier: "goToListApp", sender: self)
    }
    
    @objc
    func refreshTable() {
        // ???: why is this executing so many times on load?
        // !!!: because it is called from createProduct, which is called for each item in the response from the network request to get products from server. In general, it's better to use UITableView.insertRow(...) instead of UITableView.reloadData() when simply adding things to the table.
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}

// MARK: UITableViewDataSource
extension EmpowerPlantViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = products[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        //  'model' has all available attributes here, if needed in the future (e.g. UI development)
        cell.textLabel?.text = model.title
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "\(products.count) items"
    }
}

// MARK: UITableViewDelegate
extension EmpowerPlantViewController: UITableViewDelegate {
    // Code that executes on Click'ing table row, adds the product item to shopping cart
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let product = products[indexPath.row]
        
        ShoppingCart.addProduct(product: product)
    }
}
