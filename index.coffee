#---------------------------------------------------------------
#  :: sails-boilerplate
#  -> adapter
#---------------------------------------------------------------
async = require("async")
models = {}
parse_connection = null

titleize = (str)->
  return '' unless str?
  str = String(str).toLowerCase()
  str.replace /(?:^|\s|-)\S/g, (c) -> c.toUpperCase()

classify = (str)-> titleize(String(str).replace(/[\W_]/g, ' ')).replace(/\s/g, '')

parse_link= ->
  return parse_connection if parse_connection?
  parse_connection = require("./lib/parse.js").Parse
  parse_connection.initialize(adapter.config.application_id, adapter.config.javascript_key, adapter.config.master_key)
  return parse_connection

adapter = module.exports =

  # Set to true if this adapter supports (or requires) things like data types, validations, keys, etc.
  # If true, the schema for models using this adapter will be automatically synced when the server starts.
  # Not terribly relevant if not using a non-SQL / non-schema-ed data store
  syncable: false

  # Including a commitLog config enables transactions in this adapter
  # Please note that these are not ACID-compliant transactions:
  # They guarantee *ISOLATION*, and use a configurable persistent store, so they are *DURABLE* in the face of server crashes.
  # However there is no scheduled task that rebuild state from a mid-step commit log at server start, so they're not CONSISTENT yet.
  # and there is still lots of work to do as far as making them ATOMIC (they're not undoable right now)
  #
  # However, for the immediate future, they do a great job of preventing race conditions, and are
  # better than a naive solution.  They add the most value in findOrCreate() and createEach().
  #
  # commitLog: {
  #  identity: '__default_mongo_transaction',
  #  adapter: 'sails-mongo'
  # },

  # Default configuration for collections
  # (same effect as if these properties were included at the top level of the model definitions)
  defaults:

    # For example:
    # port: 3306,
    # host: 'localhost'

    # If setting syncable, you should consider the migrate option,
    # which allows you to set how the sync will be performed.
    # It can be overridden globally in an app (config/adapters.js) and on a per-model basis.
    #
    # drop   => Drop schema and data, then recreate it
    # alter  => Drop/add columns as necessary, but try
    # safe   => Don't change anything (good for production DBs)
    migrate: "alter"

  # This method runs when a model is initially registered at server start time



  registerCollection: (collection, cb) ->
    parse_link()
    adapter.define collection.identity, collection.definition, cb


  # The following methods are optional
  #//////////////////////////////////////////////////////////

  # Optional hook fired when a model is unregistered, typically at server halt
  # useful for tearing down remaining open connections, etc.
  teardown: (cb) ->
    cb()


  # REQUIRED method if integrating with a schemaful database
  define: (collectionName, definition, cb) ->
    cl_name = classify(collectionName)
    out_model = parse_link().Object.extend(cl_name)
    out_model._schema = definition

    models[collectionName.toLowerCase()] = out_model
    # Define a new "table" or "collection" schema in the data store
    cb()


  # REQUIRED method if integrating with a schemaful database
  describe: (collectionName, cb) ->

    # Respond with the schema (attributes) for a collection or table in the data store
    attributes = {}
    cb null, attributes


  # REQUIRED method if integrating with a schemaful database
  drop: (collectionName, cb) ->
    delete models[collectionName.toLowerCase()]
    # Drop a "table" or "collection" schema from the data store
    cb()


  # Optional override of built-in alter logic
  # Can be simulated with describe(), define(), and drop(),
  # but will probably be made much more efficient by an override here
  # alter: function (collectionName, attributes, cb) {
  # Modify the schema of a table or collection in the data store
  # cb();
  # },

  # REQUIRED method if users expect to call Model.create() or any methods
  create: (collectionName, values, cb) ->
    return cb("Model not found", null) unless models[collectionName.toLowerCase()]?
    new_model = new (models[collectionName.toLowerCase()])()
    new_model.save values,
      success: (out_elem)->
        cb null, out_elem

      error: (out_elem, error)->
        cb error, out_elem
    # Create a single new model specified by values

    # Respond with error or newly created model instance
    #cb null, values


  # REQUIRED method if users expect to call Model.find(), Model.findAll() or related methods
  # You're actually supporting find(), findAll(), and other methods here
  # but the core will take care of supporting all the different usages.
  # (e.g. if this is a find(), not a findAll(), it will only send back a single model)
  find: (collectionName, options, cb) ->
    return cb("Model not found", null) unless models[collectionName.toLowerCase()]?
    query = new (parse_link().Query)(models[collectionName.toLowerCase()])
    if (options?.where?.id?)
      query.get options.where.id,
        success: (out_elem)->
          cb null, [out_elem]
        error: (out_elem,error)->
          cb error, null
    else if(options?.where?)
      query.limit(options?.limit) if options?.limit
      query.skip(options?.skip) if options?.skip

      if options?.order
        for k, v of options?.order
          if v.toLowerCase() is "asc"
            query.ascending(k)
          else
            query.descending(k)

      for k, v of options?.where
        if _.isObject(v) and v?.comparer?
          query[v?.comparer](k, v.value)
        else
          query.equalTo(k, v)

      query.find
        success: (out_elems)->
          cb null, out_elems
        error: (out_elems,error)->
          cb error, null
    else
      return adapter.find(collectionName, {where:options}, cb)

        # ...


    # ** Filter by criteria in options to generate result set

    # Respond with an error or a *list* of models in result set

  native: (collectionName, cb) ->
     return cb("Model not found", null) unless models[collectionName.toLowerCase()]?
     cb null, models[collectionName.toLowerCase()]

  count: (collectionName, options, cb) ->
    return cb("Model not found", null) unless models[collectionName.toLowerCase()]?
    query = new (parse_link().Query)(models[collectionName.toLowerCase()])
    if(options?.where?)
      for k, v of options?.where
        if _.isObject(v) and v?.comparer?
          query[v?.comparer](k, v.value)
        else
          query.equalTo(k, v)

      query.count
        success: (out_elems_count)->
          cb null, out_elems_count
        error: (out_elems,error)->
          cb error, null
    else
      return adapter.count(collectionName, {where:options}, cb)

  # REQUIRED method if users expect to call Model.update()
  update: (collectionName, options, values, cb) ->
    adapter.find collectionName, options, (error, items)->
      return cb error, null if error?
      async.forEach items, (item, elem_cb)->
        for k, v of values
          item.set k, v
        item.save elem_cb
          # ...

      , (error)->
        return cb error, null if error?
        return cb null, items

    # ** Filter by criteria in options to generate result set

    # Then update all model(s) in the result set

    # Respond with error or a *list* of models that were updated
    #cb()


  # REQUIRED method if users expect to call Model.destroy()
  destroy: (collectionName, options, cb) ->
    adapter.find collectionName, options, (error, items)->
      return cb error, null if error?
      async.forEach items, (item, elem_cb)->
        item.destroy elem_cb
          # ...

      , (error)->
        return cb error, null if error?
        return cb null, items
    # ** Filter by criteria in options to generate result set

    # Destroy all model(s) in the result set

    # Return an error or nothing at all
    cb()


  # REQUIRED method if users expect to call Model.stream()
  stream: (collectionName, options, stream) ->

# options is a standard criteria/options object (like in find)

# stream.write() and stream.end() should be called.
# for an example, check out:
# https://github.com/balderdashy/sails-dirty/blob/master/DirtyAdapter.js#L247

#
#  **********************************************
#  * Optional overrides
#  **********************************************
#
#  // Optional override of built-in batch create logic for increased efficiency
#  // otherwise, uses create()
#  createEach: function (collectionName, cb) { cb(); },
#
#  // Optional override of built-in findOrCreate logic for increased efficiency
#  // otherwise, uses find() and create()
#  findOrCreate: function (collectionName, cb) { cb(); },
#
#  // Optional override of built-in batch findOrCreate logic for increased efficiency
#  // otherwise, uses findOrCreate()
#  findOrCreateEach: function (collectionName, cb) { cb(); }
#

#
#  **********************************************
#  * Custom methods
#  **********************************************
#
#  ////////////////////////////////////////////////////////////////////////////////////////////////////
#  //
#  // > NOTE:  There are a few gotchas here you should be aware of.
#  //
#  //    + The collectionName argument is always prepended as the first argument.
#  //      This is so you can know which model is requesting the adapter.
#  //
#  //    + All adapter functions are asynchronous, even the completely custom ones,
#  //      and they must always include a callback as the final argument.
#  //      The first argument of callbacks is always an error object.
#  //      For some core methods, Sails.js will add support for .done()/promise usage.
#  //
#  //    +
#  //
#  ////////////////////////////////////////////////////////////////////////////////////////////////////
#
#
#  // Any other methods you include will be available on your models
#  foo: function (collectionName, cb) {
#    cb(null,"ok");
#  },
#  bar: function (collectionName, baz, watson, cb) {
#    cb("Failure!");
#  }
#
#
#  // Example success usage:
#
#  Model.foo(function (err, result) {
#    if (err) console.error(err);
#    else console.log(result);
#
#    // outputs: ok
#  })
#
#  // Example error usage:
#
#  Model.bar(235, {test: 'yes'}, function (err, result){
#    if (err) console.error(err);
#    else console.log(result);
#
#    // outputs: Failure!
#  })
#
#

#////////////                 //////////////////////////////////////////
#//////////// Private Methods //////////////////////////////////////////
#////////////                 //////////////////////////////////////////