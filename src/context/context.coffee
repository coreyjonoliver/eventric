eventric = require 'eventric'

Repository        = require 'eventric/src/context/repository'
DomainEvent       = require 'eventric/src/context/domain_event'
EventBus          = require 'eventric/src/event_bus'
PubSub            = require 'eventric/src/pub_sub'
projectionService = require 'eventric/src/projection'


class Context extends PubSub

  constructor: (@name) ->
    super
    @_initialized = false
    @_params = eventric.get()
    @_di = {}
    @_aggregateRootClasses = {}
    @_adapterClasses = {}
    @_adapterInstances = {}
    @_commandHandlers = {}
    @_queryHandlers = {}
    @_domainEventClasses = {}
    @_domainEventHandlers = {}
    @_projectionClasses = []
    @_repositoryInstances = {}
    @_domainServices = {}
    @_storeClasses = {}
    @_storeInstances = {}
    @_eventBus = new EventBus


  log: eventric.log


  ###*
  * @name set
  *
  * @module Context
  *
  * @description
  * > Use as: set(key, value)
  * Configure settings for the `context`.
  *
  * @example

     exampleContext.set 'store', StoreAdapter

  *
  * @param {Object} key
  * Available keys are: `store` Eventric Store Adapter
  ###
  set: (key, value) ->
    @_params[key] = value
    @


  get: (key) ->
    @_params[key]


  ###*
  * @name emitDomainEvent
  *
  * @module Context
  *
  * @description emit Domain Event in the context
  *
  * @param {String} domainEventName Name of the DomainEvent
  * @param {Object} domainEventPayload payload for the DomainEvent
  ###
  emitDomainEvent: (domainEventName, domainEventPayload) =>
    DomainEventClass = @getDomainEvent domainEventName
    if !DomainEventClass
      throw new Error "Tried to emitDomainEvent '#{domainEventName}' which is not defined"

    domainEvent = @_createDomainEvent domainEventName, DomainEventClass, domainEventPayload
    @getDomainEventsStore().saveDomainEvent domainEvent, =>
      @publishDomainEvent domainEvent, ->


  publishDomainEvent: (domainEvent, callback=->) =>
    @_eventBus.publishDomainEvent domainEvent, callback


  _createDomainEvent: (domainEventName, DomainEventClass, domainEventPayload) ->
    new DomainEvent
      id: eventric.generateUid()
      name: domainEventName
      context: @name
      payload: new DomainEventClass domainEventPayload


  addStore: (storeName, StoreClass, storeOptions={}) ->
    @_storeClasses[storeName] =
      Class: StoreClass
      options: storeOptions
    @


  ###*
  * @name defineDomainEvent
  *
  * @module Context
  *
  * @description
  * Adds a DomainEvent Class which will be used when emitting or handling DomainEvents inside of Aggregates, Projectionpr or ProcessManagers
  *
  * @param {String} domainEventName Name of the DomainEvent
  * @param {Function} DomainEventClass DomainEventClass
  ###
  defineDomainEvent: (domainEventName, DomainEventClass) ->
    @_domainEventClasses[domainEventName] = DomainEventClass
    @


  defineDomainEvents: (domainEventClassesObj) ->
    @defineDomainEvent domainEventName, DomainEventClass for domainEventName, DomainEventClass of domainEventClassesObj
    @


  ###*
  * @name addCommandHandler
  *
  * @module Context
  *
  * @dscription
  * Use as: addCommandHandler(commandName, commandFunction)
  *
  * Add Commands to the `context`. These will be available to the `command` method after calling `initialize`.
  *
  * @example
    ```javascript
    exampleContext.addCommandHandler('someCommand', function(params, callback) {
      // ...
    });
    ```

  * @param {String} commandName Name of the command
  *
  * @param {String} commandFunction Gets `this.aggregate` dependency injected
  * `this.aggregate.command(params)` Execute command on Aggregate
  *  * `params.name` Name of the Aggregate
  *  * `params.id` Id of the Aggregate
  *  * `params.methodName` MethodName inside the Aggregate
  *  * `params.methodParams` Array of params which the specified AggregateMethod will get as function signature using a [splat](http://stackoverflow.com/questions/6201657/what-does-splats-mean-in-the-coffeescript-tutorial)
  *
  * `this.aggregate.create(params)` Execute command on Aggregate
  *  * `params.name` Name of the Aggregate to be created
  *  * `params.props` Initial properties so be set on the Aggregate or handed to the Aggregates create() method
  ###
  addCommandHandler: (commandHandlerName, commandHandlerFn) ->
    @_commandHandlers[commandHandlerName] = =>
      command =
        id: eventric.generateUid()
        name: commandHandlerName
        params: arguments[0] ? null

      _di = {}
      for diFnName, diFn of @_di
        _di[diFnName] = diFn

      repositoryCache = null
      _di.$repository = (aggregateName) =>

        if not repositoryCache
          AggregateRoot = @_aggregateRootClasses[aggregateName]
          repository = new Repository
            aggregateName: aggregateName
            AggregateRoot: AggregateRoot
            context: @
          #repository.addMiddlewares @_repositoryMiddlewares()
          repositoryCache = repository

        repositoryCache.setCommand command
        #repository.setUser user

        repositoryCache

      commandHandlerFn.apply _di, arguments
    @


  addCommandHandlers: (commandObj) ->
    @addCommandHandler commandHandlerName, commandFunction for commandHandlerName, commandFunction of commandObj
    @


  ###*
  * @name addQueryHandler
  *
  * @module Context
  *
  * @dscription
  * Use as: addQueryHandler(queryHandler, queryFunction)
  *
  * Add Commands to the `context`. These will be available to the `query` method after calling `initialize`.
  *
  * @example
    ```javascript
    exampleContext.addQueryHandler('SomeQuery', function(params, callback) {
      // ...
    });
    ```

  * @param {String} queryHandler Name of the query
  *
  * @param {String} queryFunction Function to execute on query
  ###
  addQueryHandler: (queryHandlerName, queryHandlerFn) ->
    @_queryHandlers[queryHandlerName] = => queryHandlerFn.apply @_di, arguments
    @


  addQueryHandlers: (commandObj) ->
    @addQueryHandler queryHandlerName, queryFunction for queryHandlerName, queryFunction of commandObj
    @


  ###*
  * @name addAggregate
  *
  * @module Context
  *
  * @description
  *
  * Use as: addAggregate(aggregateName, aggregateDefinition)
  *
  * Add [Aggregates](https://github.com/efacilitation/eventric/wiki/BuildingBlocks#aggregateroot) to the `context`. It takes an AggregateDefinition as argument. The AggregateDefinition must at least consists of one AggregateRoot and can optionally have multiple named AggregateEntities. The Root and Entities itself are completely vanilla since eventric follows the philosophy that your DomainModel-Code should be technology-agnostic.
  *
  * @example

  ```javascript
  exampleContext.addAggregate('Example', {
    root: function(){
      this.doSomething = function(description) {
        // ...
      }
    },
    entities: {
      'ExampleEntityOne': function() {},
      'ExampleEntityTwo': function() {}
    }
  });
  ```
  *
  * @param {String} aggregateName Name of the Aggregate
  * @param {String} aggregateDefinition Definition containing root and entities
  ###
  addAggregate: (aggregateName, AggregateRootClass) ->
    @_aggregateRootClasses[aggregateName] = AggregateRootClass
    @


  addAggregates: (aggregatesObj) ->
    @addAggregate aggregateName, AggregateRootClass for aggregateName, AggregateRootClass of aggregatesObj
    @


  ###*
  * @name subscribeToDomainEvent
  *
  * @module Context
  *
  * @description
  * Use as: subscribeToDomainEvent(domainEventName, domainEventHandlerFunction)
  *
  * Add handler function which gets called when a specific `DomainEvent` gets triggered
  *
  * @example
    ```javascript
    exampleContext.subscribeToDomainEvent('Example:create', function(domainEvent) {
      // ...
    });
    ```
  *
  * @param {String} domainEventName Name of the `DomainEvent`
  *
  * @param {Function} Function which gets called with `domainEvent` as argument
  * - `domainEvent` Instance of [[DomainEvent]]
  *
  ###
  subscribeToDomainEvent: (domainEventName, handlerFn, options = {}) ->
    domainEventHandler = () => handlerFn.apply @_di, arguments
    @_eventBus.subscribeToDomainEvent domainEventName, domainEventHandler, options
    @

  ###*
  * @name subscribeToDomainEventWithAggregateId
  *
  * @module Context
  *
  ###
  subscribeToDomainEventWithAggregateId: (domainEventName, aggregateId, handlerFn, options = {}) ->
    domainEventHandler = () => handlerFn.apply @_di, arguments
    @_eventBus.subscribeToDomainEventWithAggregateId domainEventName, aggregateId, domainEventHandler, options


  subscribeToAllDomainEvents: (handlerFn, options = {}) ->
    domainEventHandler = () => handlerFn.apply @_di, arguments
    @_eventBus.subscribeToAllDomainEvents domainEventHandler, options



  subscribeToDomainEvents: (domainEventHandlersObj) ->
    @subscribeToDomainEvent domainEventName, handlerFn for domainEventName, handlerFn of domainEventHandlersObj
    @


  ###*
  * @name addDomainService
  *
  * @module Context
  *
  * @description
  * Use as: addDomainService(domainServiceName, domainServiceFunction)
  *
  * Add function which gets called when called using $domainService
  *
  * @example
    ```javascript
    exampleContext.addDomainService('DoSomethingSpecial', function(params, callback) {
      // ...
    });
    ```
  *
  * @param {String} domainServiceName Name of the `DomainService`
  *
  * @param {Function} Function which gets called with params as argument
  ###
  addDomainService: (domainServiceName, domainServiceFn) ->
    @_domainServices[domainServiceName] = => domainServiceFn.apply @_di, arguments
    @


  addDomainServices: (domainServiceObjs) ->
    @addDomainService domainServiceName, domainServiceFn for domainServiceName, domainServiceFn of domainServiceObjs
    @


  ###*
  * @name addAdapter
  *
  * @module Context
  *
  * @description
  * Use as: addAdapter(adapterName, AdapterClass)
  *
  * Add adapter which get can be used inside of `CommandHandlers`
  *
  * @example
    ```javascript
    exampleContext.addAdapter('SomeAdapter', function() {
      // ...
    });
    ```
  *
  * @param {String} adapterName Name of Adapter
  *
  * @param {Function} Adapter Class
  ###
  addAdapter: (adapterName, adapterClass) ->
    @_adapterClasses[adapterName] = adapterClass
    @


  addAdapters: (adapterObj) ->
    @addAdapter adapterName, fn for adapterName, fn of adapterObj
    @


  ###*
  * @name addProjection
  *
  * @module Context
  *
  * @description
  * Add Projection that can subscribe to and handle DomainEvents
  *
  * @param {string} projectionName Name of the Projection
  * @param {Function} The Projection Class definition
  * - define `subscribeToDomainEvents` as Array of DomainEventName Strings
  * - define handle Funtions for DomainEvents by convention: "handleDomainEventName"
  ###
  addProjection: (projectionName, ProjectionClass) ->
    @_projectionClasses.push
      name: projectionName
      class: ProjectionClass
    @


  addProjections: (viewsObj) ->
    @addProjection projectionName, ProjectionClass for projectionName, ProjectionClass of viewsObj
    @


  ###*
  * @name initialize
  *
  * @module Context
  *
  * @description
  * Use as: initialize()
  *
  * Initializes the `context` after the `add*` Methods
  *
  * @example
    ```javascript
    exampleContext.initialize(function() {
      // ...
    })
    ```
  ###
  initialize: (callback=->) ->
    new Promise (resolve, reject) =>
      @log.debug "[#{@name}] Initializing"
      @log.debug "[#{@name}] Initializing Store"
      @_initializeStores()
      .then =>
        @log.debug "[#{@name}] Finished initializing Store"
        @_di =
          $adapter: => @getAdapter.apply @, arguments
          $query: => @query.apply @, arguments
          $domainService: =>
            (@getDomainService arguments[0]).apply @, [arguments[1], arguments[2]]
          $projectionStore: => @getProjectionStore.apply @, arguments
          $emitDomainEvent: => @emitDomainEvent.apply @, arguments

        @log.debug "[#{@name}] Initializing Adapters"
        @_initializeAdapters()
      .then =>
        @log.debug "[#{@name}] Finished initializing Adapters"
        @log.debug "[#{@name}] Initializing Projections"
        @_initializeProjections()
      .then =>
        @log.debug "[#{@name}] Finished initializing Projections"
        @log.debug "[#{@name}] Finished initializing"
        @_initialized = true
        callback()
        resolve()
      .catch (err) ->
        callback err
        reject err


  _initializeStores: ->
    new Promise (resolve, reject) =>
      stores = []
      for storeName, store of (eventric.defaults @_storeClasses, eventric.getStores())
        stores.push
          name: storeName
          Class: store.Class
          options: store.options

      eventric.eachSeries stores, (store, next) =>
        @log.debug "[#{@name}] Initializing Store #{store.name}"
        @_storeInstances[store.name] = new store.Class
        @_storeInstances[store.name].initialize @, store.options, =>
          @log.debug "[#{@name}] Finished initializing Store #{store.name}"
          next()

      , (err) ->
        return reject err if err
        resolve()


  _initializeProjections: ->
    new Promise (resolve, reject) =>
      eventric.eachSeries @_projectionClasses, (projection, next) =>
        eventNames = null
        projectionName = projection.name
        @log.debug "[#{@name}] Initializing Projection #{projectionName}"
        projectionService.initializeInstance projection, {}, @
        .then (projectionId) =>
          @log.debug "[#{@name}] Finished initializing Projection #{projectionName}"
          next()

        .catch (err) ->
          reject err

      , (err) =>
        return reject err if err
        resolve()


  _initializeAdapters: ->
    new Promise (resolve, reject) =>
      for adapterName, adapterClass of @_adapterClasses
        adapter = new @_adapterClasses[adapterName]
        adapter.initialize?()

        @_adapterInstances[adapterName] = adapter

      resolve()


  ###*
  * @name getProjection
  *
  * @module Context
  *
  * @description Get a Projection Instance after initialize()
  *
  * @param {String} projectionName Name of the Projection
  ###
  getProjection: (projectionId) ->
    projectionService.getInstance projectionId


  ###*
  * @name getAdapter
  *
  * @module Context
  *
  * @description Get a Adapter Instance after initialize()
  *
  * @param {String} adapterName Name of the Adapter
  ###
  getAdapter: (adapterName) ->
    @_adapterInstances[adapterName]


  ###*
  * @name getDomainEvent
  *
  * @module Context
  *
  * @description Get a DomainEvent Class after initialize()
  *
  * @param {String} domainEventName Name of the DomainEvent
  ###
  getDomainEvent: (domainEventName) ->
    @_domainEventClasses[domainEventName]


  ###*
  * @name getDomainService
  *
  * @module Context
  *
  * @description Get a DomainService after initialize()
  *
  * @param {String} domainServiceName Name of the DomainService
  ###
  getDomainService: (domainServiceName) ->
    @_domainServices[domainServiceName]


  ###*
  * @name getDomainEventsStore
  *
  * @module Context
  *
  * @description Get the DomainEventsStore after initialization
  ###
  getDomainEventsStore: ->
    storeName = @get 'default domain events store'
    @_storeInstances[storeName]


  saveDomainEvent: (domainEvent) ->
    new Promise (resolve, reject) =>
      @getDomainEventsStore().saveDomainEvent domainEvent, (err, events) =>
        @publishDomainEvent domainEvent
        return reject err if err
        resolve events


  findAllDomainEvents: ->
    new Promise (resolve, reject) =>
      @getDomainEventsStore().findAllDomainEvents (err, events) ->
        return reject err if err
        resolve events


  findDomainEventsByName: (findArguments...) ->
    new Promise (resolve, reject) =>
      @getDomainEventsStore().findDomainEventsByName findArguments..., (err, events) ->
        return reject err if err
        resolve events


  findDomainEventsByNameAndAggregateId: (findArguments...) ->
    new Promise (resolve, reject) =>
      @getDomainEventsStore().findDomainEventsByNameAndAggregateId findArguments..., (err, events) ->
        return reject err if err
        resolve events


  findDomainEventsByAggregateId: (findArguments...) ->
    new Promise (resolve, reject) =>
      @getDomainEventsStore().findDomainEventsByAggregateId findArguments..., (err, events) ->
        return reject err if err
        resolve events


  findDomainEventsByAggregateName: (findArguments...) ->
    new Promise (resolve, reject) =>
      @getDomainEventsStore().findDomainEventsByAggregateName findArguments..., (err, events) ->
        return reject err if err
        resolve events


  getProjectionStore: (storeName, projectionName, callback) =>
    new Promise (resolve, reject) =>
      if not @_storeInstances[storeName]
        err = "Requested Store with name #{storeName} not found"
        @log.error err
        callback? err, null
        return reject err

      @_storeInstances[storeName].getProjectionStore projectionName, (err, projectionStore) =>
        callback? err, projectionStore
        return reject err if err
        resolve projectionStore


  clearProjectionStore: (storeName, projectionName, callback) =>
    new Promise (resolve, reject) =>
      if not @_storeInstances[storeName]
        err = "Requested Store with name #{storeName} not found"
        @log.error err
        callback? err, null
        return reject err

      @_storeInstances[storeName].clearProjectionStore projectionName, (err, done) =>
        callback? err, done
        return reject err if err
        resolve done


  ###*
  * @name getEventBus
  *
  * @module Context
  *
  * @description Get the EventBus after initialization
  ###
  getEventBus: ->
    @_eventBus


  ###*
  * @name command
  *
  * @module Context
  *
  * @description
  *
  * Use as: command(command, callback)
  *
  * Execute previously added `commands`
  *
  * @example
    ```javascript
    exampleContext.command('doSomething',
    function(err, result) {
      // callback
    });
    ```
  *
  * @param {String} `commandName` Name of the CommandHandler to be executed
  * @param {Object} `commandParams` Parameters for the CommandHandler function
  * @param {Function} callback Gets called after the command got executed with the arguments:
  * - `err` null if successful
  * - `result` Set by the `command`
  ###
  command: (commandName, commandParams) ->
    @log.debug 'Got Command', commandName

    new Promise (resolve, reject) =>
      if not @_initialized
        err = 'Context not initialized yet'
        @log.error err
        err = new Error err
        return reject err

      if @_commandHandlers[commandName]
        @_commandHandlers[commandName] commandParams, (err, result) =>
          @log.debug 'Completed Command', commandName
          eventric.nextTick =>
            if err
              reject err
            else
              resolve result

      else
        err = "Given command #{commandName} not registered on context"
        @log.error err
        err = new Error err
        reject err


  ###*
  * @name query
  *
  * @module Context
  *
  * @description
  *
  * Use as: query(query, callback)
  *
  * Execute previously added `QueryHandler`
  *
  * @example
    ```javascript
    exampleContext.query('Example', {
        foo: 'bar'
      }
    },
    function(err, result) {
      // callback
    });
    ```
  *
  * @param {String} `queryName` Name of the QueryHandler to be executed
  * @param {Object} `queryParams` Parameters for the QueryHandler function
  * @param {Function} `callback` Callback which gets called after query
  * - `err` null if successful
  * - `result` Set by the `query`
  ###
  query: (queryName, queryParams) ->
    @log.debug 'Got Query', queryName

    new Promise (resolve, reject) =>
      if not @_initialized
        err = 'Context not initialized yet'
        @log.error err
        err = new Error err
        reject err
        return

      if @_queryHandlers[queryName]
        @_queryHandlers[queryName] queryParams, (err, result) =>
          @log.debug 'Completed Query', queryName
          eventric.nextTick =>
            if err
              reject err
            else
              resolve result

      else
        err = "Given query #{queryName} not registered on context"
        @log.error err
        err = new Error err
        reject err


  enableWaitingMode: ->
    @set 'waiting mode', true


  disableWaitingMode: ->
    @set 'waiting mode', false


  isWaitingModeEnabled: ->
    @get 'waiting mode'


module.exports = Context