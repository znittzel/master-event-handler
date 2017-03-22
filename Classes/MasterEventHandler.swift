//
//  EventHandler.swift
//
//  Created by Rikard Olsson (SE) on 17/05/16.

/*
 * Class Event<T>.
 * Is used by Slave, Multi -and MasterEventHandler. Can be used as a custom event handler, just change to "public"
 */
public class REvent<T> {
    
    typealias EventHandler = (T) -> ()
    
    private var eventHandlers = [EventHandler]()
    
    func addHandler(_ handler: @escaping EventHandler) {
        eventHandlers.append(handler)
    }
    
    func raise(_ data: T) {
        for handler in eventHandlers {
            handler(data)
        }
    }
}

/*
 * Class SlaveEventHandler.
 * Is used by MasterEventHandler. Can be used as a single object and would work the way same as a MasterEventHandler -slave, just change to "public".
 */
public class SlaveEventHandler {
    private var eventHandler = REvent<[String]?>()
    public var numberToFetch = 1
    private var numberOfFetches = 0
    /*
     * Loads an event on creating object.
     */
    init(event: @escaping ([String]?) -> Void, numberToFetch: Int = 1) {
        load(event)
        self.numberToFetch = numberToFetch
    }
    
    /*
     * Loads an event.
     */
    func load(_ event: @escaping ([String]?) -> Void) {
        eventHandler.addHandler(event)
    }
    
    /*
     * Fires all the loaded events.
     */
    func fire(_ error: [String]?) {
        eventHandler.raise(error)
    }
    
    func setNumberToFetch(numberToFetch: Int) {
        self.numberToFetch = numberToFetch
    }
    
    /*
     * Increases the number of fetches that has been made by this Slave Event
     */
    func increaseNumberOfFetches() {
        self.numberOfFetches += 1
    }
    
    /*
     * Checking if slave is ready
     */
    func isReady() -> Bool {
        return self.numberOfFetches == self.numberToFetch
    }
    
    /*
     * Fireing events manually
     */
    func fireManually() {
        eventHandler.raise(nil)
    }
}

private func == (lmeh: MultiEventHandlerNames, rmeh: MultiEventHandlerNames) -> Bool {
    return lmeh.hashValue == rmeh.hashValue
}
private class MultiEventHandlerNames : Hashable {
    public var names = Set<String>()
    public var hashValue: Int
    
    init(names: Set<String>) {
        self.names = names
        self.hashValue = names.hashValue
    }
}

private class MultiEventHandler {
    // MARK: PRIVATE VARS
    private var multipleSlavesFired: [String : Bool]
    private var slaveEventHandler: SlaveEventHandler
    
    // MARK: INIT FUNCTIONS
    init(_ event: @escaping ([String]?) -> Void) {
        self.multipleSlavesFired = [String : Bool]()
        self.slaveEventHandler = SlaveEventHandler(event: event)
    }
    
    // MARK: FUNCIONS
    /*
     * Adds a slave name to multipleSlavesFired. Returns true if appending is successfull.
     */
    func addSlaveName(name: String) -> Bool {
        var result = false
        if multipleSlavesFired[name] == nil {
            multipleSlavesFired[name] = false
            
            result = true
        }
        
        return result
    }
    
    /*
     * Tells multipleSlavesFired that *name* -slave has fired. If all has been fired, this slaveEventHandler will fire.
     */
    func willFireIfAllFired(name: String) ->Bool {
        var result = false
        
        if self.multipleSlavesFired[name] != nil {
            self.multipleSlavesFired[name] = true
            
            let shotsBeenFired = multipleSlavesFired.filter({ (shot) -> Bool in
                return shot.1
            })
            
            if shotsBeenFired.count == self.multipleSlavesFired.count {
                self.slaveEventHandler.fireManually()
                
                result = true
            }
        }
        
        return result
    }
}


/**
 * Class MasterEventHandler.
 * Load master or a custom slave with function(s). Call fetch* with your own function to finally call "fire()" and the custom slaves will fire.
 * When all slaves has been fired the master will fire. You can fire the master manually by calling "fire()" in the "fetchMaster()" -function.
 *
 * Example:
 // Initialize a MasterHandler
 let eventHandler = MasterEventHandler()
 
 // Load a slave by
 eventHandler.loadSlave("example", event: {
 (error) in
 if error == nil {
 // Do something with your fetched data
 } else {
 // Handle error
 }
 })
 
 // Fetch a slave by
 eventHandler.fetchSlave("")
 
 
 */
class MasterEventHandler {
    // MARK: PRIVATE VARS
    private var masterHandler : REvent<[String]?>
    private var masterError : [String]?
    private var slaveErrors : [String: [String]]
    private var slaveHandler : [String : SlaveEventHandler]
    private var numberOfSlavesFired : Int
    
    // MARK: EXCLUSIVE PRIVATE VARS
    private var multiEventHandler: [MultiEventHandlerNames: MultiEventHandler]
    
    // MARK: INIT FUNCITONS
    init() {
        masterHandler = REvent<[String]?>()
        slaveHandler = [String : SlaveEventHandler]()
        slaveErrors = [String: [String]]()
        multiEventHandler = [MultiEventHandlerNames: MultiEventHandler]()
        
        numberOfSlavesFired = 0
    }
    
    // MARK: PRIVATE FUNCTIONS
    /*
     * Resets the MasterEventHandler to when it was first initialized.
     */
    private func __reset() {
        self.masterHandler = REvent<[String]?>()
        self.slaveHandler = [String : SlaveEventHandler]()
        self.masterError = nil
        numberOfSlavesFired = 0
    }
    
    // MARK: PUBLIC FUNCTIONS
    /*
     * Loads the master with an event.
     */
    func loadMaster (_ event: @escaping ([String]?) -> Void) {
        masterHandler.addHandler(event)
    }
    
    /*
     * Fires masters event if ready
     */
    func fireMasterIfReady() -> Bool {
        var result = false
        if self.numberOfSlavesFired == self.slaveHandler.count {
            var slaveErrors = [String]()
            
            for (_, errors) in self.slaveErrors {
                for error in errors {
                    slaveErrors.append(error)
                }
            }
            
            self.masterHandler.raise(slaveErrors)
            self.__reset()
            
            result = true
        }
        
        return result
    }
    
    /*
     * Loads a custom made slave with an event. If numberToFetch is set, then it wont fire until numberToFetch has been reached
     */
    func loadSlave (name: String, numberToFetch: Int = 1, event: @escaping ([String]?) -> Void) -> SlaveEventHandler {
        if slaveHandler[name] == nil {
            slaveHandler[name] = SlaveEventHandler(event: event, numberToFetch: numberToFetch)
        } else {
            slaveHandler[name]!.load(event)
        }
        
        return slaveHandler[name]!
    }
    
    /*
     * Loads a multi load. Will not load if slaves doesn't exists. If the slaves been fired, this will fire. Returns true successfully loaded.
     */
    func loadAMultiSlave(slaveNames: [String], event: @escaping ([String]?) -> Void) -> Bool {
        var result = false
        
        if !slaveNames.isEmpty {
            var allIsLoaded = true
            var multiSlaveStringNames = Set<String>()
            // allIsLoaded will be false if one is false
            for slaveName in slaveNames {
                
                // Build name
                multiSlaveStringNames.insert(slaveName)
                
                // Check if slave exists
                if self.slaveHandler[slaveName] != nil && allIsLoaded {
                    allIsLoaded = true
                } else {
                    allIsLoaded = false
                }
            }
            
            // All is loaded, good to go
            if allIsLoaded {
                // Instansiate a name handler
                let multiSlaveName = MultiEventHandlerNames(names: multiSlaveStringNames)
                
                self.multiEventHandler[multiSlaveName] = MultiEventHandler(event)
                
                // Load 'em up
                for slaveName in slaveNames {
                    _ = self.multiEventHandler[multiSlaveName]!.addSlaveName(name: slaveName)
                }
                
                result = true
            }
        }
        
        
        return result
    }
    
    /*
     * Will fire multiple shots if all assigned slaves to MultiEventHandler has been fired.
     */
    internal func fireMultipleSlavesIfReady(_ name: String) -> Bool {
        var result = false
        
        let multiEventHandlers = self.multiEventHandler.filter { (item) -> Bool in
            return item.0.names.contains(name)
        }
        
        if !multiEventHandlers.isEmpty {
            for multiEventHandler in multiEventHandlers {
                result = multiEventHandler.1.willFireIfAllFired(name: name)
                
                if result {
                    self.multiEventHandler.removeValue(forKey: multiEventHandler.0)
                }
            }
        }
        
        return result
    }
    
    /*
     * Runs the callback function and fires the slave. If all the slaves has been fired, the master will fire.
     */
    func fetchSlave (name: String, callback: (_ index: Int, _ fire: @escaping ([String]?) -> Void) -> Void) {
        if slaveHandler[name] != nil {
            if let slave = self.slaveHandler[name] {
                for i in 0..<slave.numberToFetch {
                    callback(i, { (error) in
                        
                        // Increase number of fetches to this slave
                        slave.increaseNumberOfFetches()
                        
                        if slave.isReady() {
                            _ = self.fireSlaveManually(name: name, error: error)
                            if error != nil {
                                self.masterError = error
                            }
                        }
                    })
                }
            }
        }
    }
    
    /*
     * Runs the callback function and fires the slave. If all the slaves has been fired, the master will fire.
     */
    /*func fetchSlave (slaveHandler: SlaveEventHandler, callback: (_ index: Int, _ fire: (Error?) -> Void) -> Void) {
     if let slave = self.slaveHandler {
     for i in 0..<slave.numberToFetch {
     callback(index: i, fire: { (error) in
     
     // Increase number of fetches to this slave
     slave.increaseNumberOfFetches()
     
     if slave.isReady() {
     self.fireSlaveManually(name, error: error)
     if error != nil {
     self.masterError = error
     }
     }
     })
     }
     }
     }*/
    
    /*
     * Loads the master with and event and then fires it on callback.
     */
    func loadAndFetchMaster(event: @escaping ([String]?) -> Void, callback: (_ fire: ([String]?) -> Void) -> Void) {
        loadMaster(event)
        fetchMaster(callback: callback)
    }
    
    /*
     * Runs the callback function and fires the master.
     */
    func fetchMaster(callback: (_ fire: ([String]?) -> Void) -> Void) {
        callback({ (error) in
            self.masterHandler.raise(error)
            self.__reset()
        })
    }
    
    /*
     * Fires slave manually. Returns true if fired
     */
    func fireSlaveManually(name: String, error: [String]?) -> Bool {
        var result = false
        if let slave = self.slaveHandler[name] {
            slave.fire(error)
            
            if error != nil {
                self.slaveErrors[name] = error
            }
            
            self.numberOfSlavesFired += 1
            
            _ = self.fireMasterIfReady()
            _ = self.fireMultipleSlavesIfReady(name)
            
            result = true
        }
        
        return result
    }
    
    /*
     * Returns all collected errors from Slaves
     */
    func getAllErrors() -> [String: [String]] {
        return self.slaveErrors
    }
}
