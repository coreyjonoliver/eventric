GlobalContext = require './global_context'
RemoteInMemory = require './remote/inmemory'
Remote = require './remote'
Projection = require './projection'
Context = require './context'
StoreInMemory = require './store/inmemory'

class Eventric

  constructor: ->
    @_contexts = {}
    @_params = {}
    @_domainEventHandlers = {}
    @_domainEventHandlersAll = []
    @_storeClasses = {}
    @_remoteEndpoints = []
    @_globalProjectionClasses = []

    @_globalContext = new GlobalContext
    @_projectionService = new Projection @_globalContext
    @addRemoteEndpoint 'inmemory', RemoteInMemory.endpoint
    @addStore 'inmemory', StoreInMemory
    @set 'default domain events store', 'inmemory'


  set: (key, value) ->
    @_params[key] = value


  get: (key) ->
    if not key
      @_params
    else
      @_params[key]


  addStore: (storeName, StoreClass, storeOptions = {}) ->
    @_storeClasses[storeName] =
      Class: StoreClass
      options: storeOptions


  getStores: ->
    @_storeClasses


  context: (name) ->
    if !name
      error = 'Contexts must have a name'
      @log.error error
      throw new Error error

    context = new Context name

    @_delegateAllDomainEventsToGlobalHandlers context
    @_delegateAllDomainEventsToRemoteEndpoints context

    @_contexts[name] = context

    context


  # TODO: Reconsider/Remove when adding EventStore
  initializeGlobalProjections: ->
    Promise.all @_globalProjectionClasses.map (GlobalProjectionClass) =>
      @_projectionService.initializeInstance '', new GlobalProjectionClass, {}


  # TODO: Reconsider/Remove when adding EventStore
  addGlobalProjection: (ProjectionClass) ->
    @_globalProjectionClasses.push ProjectionClass


  getRegisteredContextNames: ->
    Object.keys @_contexts


  getContext: (name) ->
    @_contexts[name]


  remote: (contextName) ->
    if !contextName
      error = 'Missing context name'
      @log.error error
      throw new Error error
    new Remote contextName


  addRemoteEndpoint: (remoteName, remoteEndpoint) ->
    @_remoteEndpoints.push remoteEndpoint
    remoteEndpoint.setRPCHandler @_handleRemoteRPCRequest


  _handleRemoteRPCRequest: (request, callback) =>
    context = @getContext request.contextName
    if not context
      error = new Error "Tried to handle Remote RPC with not registered context #{request.contextName}"
      @log.error error.stack
      callback error, null
      return

    if Remote.ALLOWED_RPC_OPERATIONS.indexOf(request.functionName) is -1
      error = new Error "RPC operation '#{request.functionName}' not allowed"
      callback error, null
      return

    if request.functionName not of context
      error = new Error "Remote RPC function #{request.functionName} not found on Context #{request.contextName}"
      @log.error error.stack
      callback error, null
      return

    context[request.functionName] request.args...
    .then (result) ->
      callback null, result
    .catch (error) ->
      callback error


  _delegateAllDomainEventsToGlobalHandlers: (context) ->
    context.subscribeToAllDomainEvents (domainEvent) =>
      eventHandlers = @getDomainEventHandlers context.name, domainEvent.name
      for eventHandler in eventHandlers
        eventHandler domainEvent


  _delegateAllDomainEventsToRemoteEndpoints: (context) ->
    context.subscribeToAllDomainEvents (domainEvent) =>
      @_remoteEndpoints.forEach (remoteEndpoint) ->
        remoteEndpoint.publish context.name, domainEvent.name, domainEvent
        if domainEvent.aggregate
          remoteEndpoint.publish context.name, domainEvent.name, domainEvent.aggregate.id, domainEvent


  subscribeToDomainEvent: ([contextName, eventName]..., eventHandler) ->
    contextName ?= 'all'
    eventName ?= 'all'

    if contextName is 'all' and eventName is 'all'
      @_domainEventHandlersAll.push eventHandler
    else
      @_domainEventHandlers[contextName] ?= {}
      @_domainEventHandlers[contextName][eventName] ?= []
      @_domainEventHandlers[contextName][eventName].push eventHandler


  getDomainEventHandlers: (contextName, domainEventName) ->
    [].concat (@_domainEventHandlers[contextName]?[domainEventName] ? []),
              (@_domainEventHandlers[contextName]?.all ? []),
              (@_domainEventHandlersAll ? [])


  # TODO: Use existing npm module
  defaults: (options, optionDefaults) ->
    allKeys = [].concat (Object.keys options), (Object.keys optionDefaults)
    for key in allKeys when !options[key] and optionDefaults[key]
      options[key] = optionDefaults[key]
    options

module.exports = Eventric
